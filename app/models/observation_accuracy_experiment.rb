# frozen_string_literal: true

class ObservationAccuracyExperiment < ApplicationRecord
  has_many :observation_accuracy_samples, dependent: :destroy
  has_many :observation_accuracy_validators, dependent: :destroy

  attribute :sample_size, :integer, default: 100
  attribute :validator_redundancy_factor, :integer, default: 5
  attribute :improving_id_threshold, :integer, default: 3
  attribute :recent_window, :string, default: 1.year.ago.strftime( "%Y-%m-%d" )
  attribute :taxon_id, :integer

  after_create :generate_sample

  def quality_metric_observation_ids( observation_ids, metrics )
    QualityMetric.
      select( :observation_id ).
      where( observation_id: observation_ids, metric: metrics ).
      group( :observation_id, :metric ).
      having(
        "COUNT( CASE WHEN agree THEN 1 ELSE NULL END ) < COUNT( CASE WHEN agree THEN NULL ELSE 1 END )"
      ).
      distinct.pluck( :observation_id )
  end

  def assess_quality( test_taxon_id, groundtruth_taxon_id, disagreement, previous_observation_taxon_id )
    test_taxon = Taxon.find( test_taxon_id )
    groundtruth_taxon = Taxon.find( groundtruth_taxon_id )
    return 1 if groundtruth_taxon_id == test_taxon_id || groundtruth_taxon.descendant_of?( test_taxon )

    return 0 if !groundtruth_taxon.in_same_branch_of?( test_taxon ) ||
      ( groundtruth_taxon.ancestor_of?( test_taxon ) &&
      disagreement && previous_observation_taxon_id == test_taxon_id )

    nil
  end

  def fetch_top_iders( window: nil, taxon_id: nil, size: nil )
    params = { d1: window, taxon_id: taxon_id }.compact
    result = INatAPIService.get( "/observations/identifiers", params )
    iders = result&.results&.to_h {| r | [r["user_id"], r["count"]] } || {}
    iders = iders.first( size ).to_h if size
    iders
  end

  def get_improving_identifiers( candidate_iders: nil, taxon_id: nil, window: nil, page: 1 )
    params = {
      category: "improving",
      per_page: 200,
      page: page,
      user_id: candidate_iders,
      d1: window,
      taxon_id: taxon_id
    }.compact
    ids = INatAPIService.get( "/identifications", params )
    ids&.results&.map {| r | r.dig( "user", "id" ) } || []
  end

  def get_qualified_candidates( taxon_id: nil, window: nil, top_iders_only: true )
    if top_iders_only
      candidate_top_taxon_iders = fetch_top_iders( window: window, taxon_id: taxon_id ).
        select {| _, v | v >= improving_id_threshold }.keys
      return [] if candidate_top_taxon_iders.empty?

    else
      candidate_top_taxon_iders = nil
    end
    improving_identifiers = []
    enough_candidates = false
    page = 1
    sorted_frequency_hash = {}
    until enough_candidates
      new_values = get_improving_identifiers(
        candidate_iders: candidate_top_taxon_iders,
        taxon_id: taxon_id,
        window: window,
        page: page
      )
      break if new_values.empty?

      improving_identifiers.concat( new_values )
      frequency_hash = improving_identifiers.group_by( &:itself ).transform_values( &:count )
      sorted_frequency_hash = frequency_hash.sort_by {| _, count | -count }.to_h
      enough_candidates = sorted_frequency_hash.count > validator_redundancy_factor &&
        sorted_frequency_hash.values[validator_redundancy_factor - 1] >= improving_id_threshold
      page += 1
    end
    sorted_frequency_hash.select {| _, v | v >= improving_id_threshold }.keys.first( validator_redundancy_factor * 2 )
  end

  # Qualified candidate identifiers have made at least improving_id_threshold number of improving IDs
  # preferably within recent_window. We want up to validator_redundancy_factor of each. Every taxon
  # might not have qualified identifers. Its slow because we have to make idententifications API calls
  def get_candidate_identifiers_by_taxon( observation_ids_grouped_by_taxon_id, top_50_iders )
    root_id = Taxon::LIFE.id
    identifiers_by_taxon_id = {}
    counter = 0
    denom = observation_ids_grouped_by_taxon_id.count
    observation_ids_grouped_by_taxon_id.each_key do | taxon_id |
      identifiers_by_taxon_id[taxon_id] = if taxon_id == root_id
        qualified_candidates = top_50_iders.select {| _, v | v >= improving_id_threshold }
        qualified_candidates.keys[0..( validator_redundancy_factor - 1 )] || []
      else
        recent_qualified_candidates = get_qualified_candidates(
          taxon_id: taxon_id,
          window: recent_window,
          top_iders_only: true
        )
        if recent_qualified_candidates.count < validator_redundancy_factor
          top_ider_qualified_candidates = get_qualified_candidates(
            taxon_id: taxon_id,
            window: nil,
            top_iders_only: true
          )
          recent_qualified_candidates = recent_qualified_candidates.
            union( top_ider_qualified_candidates ).first( validator_redundancy_factor * 2 )
        end
        if recent_qualified_candidates.count < validator_redundancy_factor
          all_qualified_candidates = get_qualified_candidates(
            taxon_id: taxon_id,
            window: nil,
            top_iders_only: false
          )
          recent_qualified_candidates = recent_qualified_candidates.
            union( all_qualified_candidates ).first( validator_redundancy_factor * 2 )
        end
        recent_qualified_candidates
      end
      counter += 1
      puts "Processed #{counter} records of #{denom}" if ( counter % 10 ).zero?
    end
    identifiers_by_taxon_id
  end

  def associate_observations_with_identifiers( obs_ids_grouped_by_taxon_id, identifiers_by_taxon_id, top_iders )
    validator_candidates = identifiers_by_taxon_id.values.flatten.uniq
    observation_ids = obs_ids_grouped_by_taxon_id.values.flatten.uniq
    observer_hash = Observation.find( observation_ids ).map {| o | [o.id, o.user_id] }.to_h
    user_blocks = UserBlock.
      where( blocked_user_id: validator_candidates ).
      group( :blocked_user_id ).
      pluck( :blocked_user_id, Arel.sql( "ARRAY_AGG(user_id)" ) ).to_h
    observation_identifications_hash = Observation.
      joins( :identifications ).
      where( id: observation_ids ).
      group( :id ).
      pluck( :id, Arel.sql( "ARRAY_AGG(DISTINCT identifications.user_id) AS user_ids" ) ).to_h
    associations = Hash.new {| hash, key | hash[key] = [] }
    user_obs_count = Hash.new( 0 )
    obs_ids_grouped_by_taxon_id.each do | taxon_id, obs_ids |
      sorted_identifiers = identifiers_by_taxon_id[taxon_id] || []
      obs_ids.each do | obs_id |
        top_ider_candidates = sorted_identifiers.reject {| user_id | user_obs_count[user_id] >= 100 }.
          select {| user_id | top_iders.keys.include? user_id }
        top_ider_candidates.concat( sorted_identifiers.reject {| user_id | user_obs_count[user_id] >= 100 }.
          reject {| user_id | top_ider_candidates.include? user_id } )
        top_ider_candidates = top_ider_candidates.reject do | user_id |
          user_blocks[user_id] && ( user_blocks[user_id].include? observer_hash[obs_id] )
        end
        if top_ider_candidates.length > validator_redundancy_factor
          observation_identifications = observation_identifications_hash[obs_id] || []
          running_length = top_ider_candidates.length
          top_ider_candidates = top_ider_candidates.reject do | user_id |
            include_user = observation_identifications.include?( user_id ) &&
              running_length > validator_redundancy_factor
            running_length -= 1 if include_user
            include_user
          end
        end
        top_ider_candidates.each {| user_id | user_obs_count[user_id] += 1 }
        associations[obs_id] += top_ider_candidates
      end
    end
    associations.each_with_object( {} ) do | ( obs_id, user_ids ), result |
      user_ids.each do | user_id |
        result[user_id] ||= []
        result[user_id] << obs_id
      end
    end
  end

  def distribute_to_validators( samples )
    puts "Divide up the sample among identifiers"
    puts "with a validator redundancy factor of #{validator_redundancy_factor}..."
    observation_ids_grouped_by_taxon_id = samples.group_by( &:taxon_id ).
      transform_values {| sample | sample.map( &:observation_id ) }

    puts "Fetch the top IDers..."
    top_iders = fetch_top_iders( window: recent_window )

    puts "Select identifiers for each taxon represented in the sample (this may take a while)..."
    identifiers_by_taxon_id = get_candidate_identifiers_by_taxon(
      observation_ids_grouped_by_taxon_id,
      top_iders.first( 50 ).to_h
    )

    puts "Assign observations to identifiers..."
    obs_id_by_user = associate_observations_with_identifiers(
      observation_ids_grouped_by_taxon_id,
      identifiers_by_taxon_id,
      top_iders
    )

    puts "Optimally reduce to validator redundancy factor and save..."
    sorted_obs_id_by_user = obs_id_by_user.sort_by {| _user_id, observation_ids | observation_ids.length }.to_h
    sorted_obs_id_by_user.each do | user_id, observation_ids |
      if observation_ids.all? do | obs_id |
        sorted_obs_id_by_user.count {| _, obs_ids | obs_ids.include?( obs_id ) } > validator_redundancy_factor
      end
        sorted_obs_id_by_user.delete( user_id )
      else
        observation_validator = ObservationAccuracyValidator.
          create( user_id: user_id, observation_accuracy_experiment_id: id )
        observation_validator.observation_accuracy_samples << ObservationAccuracySample.
          where( observation_id: observation_ids, observation_accuracy_experiment_id: id )
      end
    end
  end

  def generate_sample
    last_obs = Observation.last
    return nil if last_obs.nil?

    puts "Generating sample of size #{sample_size}..."
    start_time = Time.now
    sample_size = self.sample_size
    taxon_id = self.taxon_id
    ceil = last_obs.id
    random_numbers = ( 1..ceil ).to_a.sample( sample_size * 2 )
    o = if taxon_id.nil? || taxon_id == Taxon::LIFE.id
      Observation.select( :id ).where( "id IN (?)", random_numbers )
    else
      taxon = Taxon.find( taxon_id )
      ancestry_string = "#{taxon.ancestry}/#{taxon.id}"
      Observation.
        joins( :taxon ).select( "observations.id" ).
        where(
          "( taxa.id = ? OR taxa.ancestry = ? OR taxa.ancestry LIKE ( ? ) ) AND observations.id IN ( ? )",
          taxon_id,
          ancestry_string,
          "#{ancestry_string}/%",
          random_numbers
        )
    end
    o = o.map {| a | a[:id] }.shuffle[0..( sample_size - 1 )]
    observations = Observation.includes( :taxon ).find( o )

    puts "Fetching continent groupings"
    continent_obs = {}
    continents = Place.where( admin_level: -10 ).map( &:id )
    o.each_slice( 100 ) do | batch |
      oo = INatAPIService.observations( id: batch )
      oo.results.each do | o_api |
        continent = ( continents & o_api["place_ids"] ).first
        continent_obs[o_api["id"]] = continent
      end
    end
    continent_key = Place.find( continents ).map {| a | [a.id, a.name] }.to_h

    puts "Fetching number of descendants"
    root_id = Taxon::LIFE.id
    taxon_descendant_count = {}
    observations.pluck( :taxon_id ).uniq.each do | obs_taxon_id |
      obs_taxon_id = root_id if obs_taxon_id.nil?
      parent = Taxon.find( obs_taxon_id )
      if parent.rank_level <= 10
        leaf_descendants = 1
      else
        parent_ancestry = if obs_taxon_id == root_id
          obs_taxon_id.to_s
        else
          "#{parent.ancestry}/#{parent.id}"
        end
        taxa = Taxon.select( :ancestry, :id ).
          where(
            "rank_level >= 10 AND ( ancestry = ? OR ancestry LIKE ( ? ) ) AND is_active = TRUE",
            parent_ancestry,
            "#{parent_ancestry}/%"
          )
        ancestors = taxa.map {| t | t.ancestry.split( "/" ).map( &:to_i ) }.flatten.uniq
        taxon_ids = taxa.map( &:id ).uniq
        leaf_descendants = ( taxon_ids - ancestors ).count
      end
      taxon_descendant_count[obs_taxon_id] = ( leaf_descendants.zero? ? 1 : leaf_descendants )
    end

    iconic_taxon_key = Taxon::ICONIC_TAXA.map {| t | [t.id, t.name] }.to_h
    no_media = Observation.includes( :photos, :sounds ).
      where( id: o ).
      where( photos: { id: nil }, sounds: { id: nil } ).pluck( :id )
    sounds_only = Observation.includes( :photos, :sounds ).
      where( id: o ).
      where( photos: { id: nil }, sounds: "sounds.id IS NOT NULL" ).
      pluck( :id )
    has_cid = Observation.
      where( "id IN ( ? ) AND community_taxon_id IS NOT NULL AND community_taxon_id = taxon_id", o ).
      pluck( :id )
    captive = quality_metric_observation_ids( o, "wild" )
    no_evidence = quality_metric_observation_ids( o, ["evidence"] )
    other_dqa_issue = quality_metric_observation_ids( o, ["location", "date", "recent"] )

    obs_data = observations.map do | obs |
      {
        observation_accuracy_experiment_id: id,
        observation_id: obs.id,
        taxon_id: obs.taxon_id.nil? ? root_id : obs.taxon_id,
        quality_grade: obs.quality_grade,
        year: obs.created_at.year,
        iconic_taxon_name: iconic_taxon_key[obs.iconic_taxon_id],
        continent: continent_key[continent_obs[obs.id]],
        taxon_observations_count: obs.taxon&.observations_count,
        taxon_rank_level: obs.taxon_id.nil? ? Taxon::ROOT_LEVEL : obs.taxon&.rank_level,
        descendant_count: taxon_descendant_count[obs.taxon_id.nil? ? root_id : obs.taxon_id],
        no_evidence: no_media.include?( obs.id ) || no_evidence.include?( obs.id ),
        sounds_only: sounds_only.include?( obs.id ),
        has_cid: has_cid.include?( obs.id ),
        captive: captive.include?( obs.id ),
        other_dqa_issue: other_dqa_issue.include?( obs.id )
      }
    end

    samples = ObservationAccuracySample.create!( obs_data )

    distribute_to_validators( samples.select {| a | a.no_evidence == false } )

    self.sample_generation_date = Time.now
    save!

    end_time = Time.now
    duration = end_time - start_time
    puts "Sample generated in #{duration} seconds."
  end

  def contact_validators( validator_deadline_date: 1.week.from_now.strftime( "%Y-%m-%d" ) )
    observation_accuracy_validators.each do | validator |
      if Emailer.observation_accuracy_validator_contact( validator, validator_deadline_date ).deliver_now
        validator.email_date = Time.now
        validator.save!
      end
    end
    self.validator_contact_date = Time.now
    self.validator_deadline_date = validator_deadline_date
    save!
  end

  def calculate_precision( number )
    1 / ( number.zero? ? 1 : number ).to_f
  end

  def assess_experiment
    groundtruths = {}
    observation_accuracy_validators.each do | validator |
      obs_ids = validator.observation_accuracy_samples.pluck( :observation_id )
      user_id = validator.user_id
      groundtruth_taxa = Identification.
        select( "DISTINCT ON ( observation_id ) observation_id, taxon_id, " \
          "disagreement, previous_observation_taxon_id" ).
        where( observation_id: obs_ids, user_id: user_id, current: true ).
        order( "observation_id DESC, created_at DESC" ).
        pluck( :observation_id, :taxon_id, :disagreement, :previous_observation_taxon_id ).
        group_by( &:shift ).
        transform_values do | values |
          values.map {| v | { taxon_id: v[0], disagreement: v[1], previous_observation_taxon_id: v[2] } }
        end
      groundtruths[user_id] = groundtruth_taxa
      validation_count = groundtruth_taxa.count
      if validation_count.positive?
        validator.validation_count = validation_count
        validator.save!
      end
    end

    responding_validators = groundtruths.values.reject( &:empty? ).count
    validated_observations = groundtruths.values.map( &:keys ).flatten.uniq.count

    observation_accuracy_samples.each do | sample |
      oid = sample.observation_id
      test_taxon = sample.taxon_id
      matches = groundtruths.values.map {| groundtruth_taxa | groundtruth_taxa[oid] }.compact.flatten
      if matches.empty?
        sample.correct = nil
        sample.reviewers = 0
      else
        qualities_for_row = []
        matches.each do | match |
          groundtruth_taxon = match[:taxon_id]
          disagreement = match[:disagreement]
          previous_observation_taxon_id = match[:previous_observation_taxon_id]
          quality = assess_quality( test_taxon, groundtruth_taxon, disagreement, previous_observation_taxon_id )
          qualities_for_row << quality
        end
        sample.correct = if !qualities_for_row.map( &:nil? ).all? &&
            qualities_for_row.compact.uniq.count > 1
          # conflict
          -1
        elsif qualities_for_row.map( &:nil? ).all?
          nil
        else
          qualities_for_row.compact[0]
        end
        sample.reviewers = matches.count
      end
      sample.save!
    end

    if observation_accuracy_samples.select {| q | q.correct == -1 }.count.positive?
      obs_ids = observation_accuracy_samples.select {| q | q.correct == -1 }.map( &:observation_id ).join( "," )
      puts "There is at least one conflict"
      puts FakeView.identify_observations_url( reviewed: "any", quality_grade: "needs_id,research,casual", id: obs_ids )
    end
    self.assessment_date = Time.now
    self.responding_validators = responding_validators
    self.validated_observations = validated_observations
    save!
  end

  def get_sample_for_user_id( user_id )
    validator = ObservationAccuracyValidator.
      where( user_id: user_id, observation_accuracy_experiment_id: id ).first
    return nil unless validator

    samples = validator.observation_accuracy_samples
    return nil unless samples.count.positive?

    oids = samples.map( &:observation_id ).join( "," )
    FakeView.identify_observations_url(
      place_id: "any",
      reviewed: "any",
      quality_grade: "needs_id,research,casual",
      id: oids
    )
  end

  def get_top_level_stats( subset )
    subset_filter = case subset
    when "verifiable_results" then "( quality_grade = 'research' OR quality_grade = 'needs_id' )"
    when "all_results" then nil
    else "quality_grade = 'research'"
    end

    counts = {
      incorrect: observation_accuracy_samples.
        where( [subset_filter, "correct = 0"].compact.join( " AND " ).to_s ).count,
      uncertain: observation_accuracy_samples.
        where( [subset_filter, "( correct IS NULL OR correct = -1 )"].compact.join( " AND " ).to_s ).count,
      correct: observation_accuracy_samples.
        where( [subset_filter, "correct = 1"].compact.join( " AND " ).to_s ).count
    }
    total = counts.values.sum
    stats = counts.transform_values {| count | ( total.zero? ? 0 : count / total.to_f * 100 ).round( 2 ) }

    descendant_counts = observation_accuracy_samples.where( subset_filter.to_s ).map( &:descendant_count )
    mean_precision = if descendant_counts.empty?
      0
    else
      descendant_counts.map {| descendant_count | calculate_precision( descendant_count ) }.
        sum / descendant_counts.count
    end

    {
      correct: stats[:correct],
      uncertain: stats[:uncertain],
      incorrect: stats[:incorrect],
      precision: ( mean_precision * 100 ).round( 2 ),
      sample_size: descendant_counts.count
    }
  end

  def taxon_rank_level_categories( key )
    case key
    when 5 then "subspecies"
    when 10 then "species"
    when 11..20 then "sp.-gen."
    when 21..30 then "gen.-fam."
    when 31..40 then "fam.-ord."
    when 41..50 then "ord.-class"
    when 51..60 then "class-phy."
    when 61..70 then "phy.-king."
    else "life"
    end
  end

  def taxon_observations_count_categories( key )
    case key
    when 1..100 then "1-100"
    when 101..1_000 then "100-1k"
    when 1_001..10_000 then "1k-10k"
    when 10_001..100_000 then "10k-100k"
    else ">100k"
    end
  end

  def normalize_counts( counts )
    total = counts.values.flatten.count
    stats = counts.transform_values do | ids |
      norm = ( total.zero? ? 0 : ids.count / total.to_f * 100 ).round( 2 )
      {
        url: FakeView.observations_url( verifiable: "any", place_id: "any", id: ids.join( "," ) ),
        height: norm,
        altheight: ids.count
      }
    end
    [stats[:incorrect], stats[:uncertain], stats[:correct]]
  end

  def group_counts( ungrouped_counts, key )
    counts = Hash.new {| h, k | h[k] = { correct: [], uncertain: [], incorrect: [] } }
    ungrouped_counts.reverse_each do | k, v |
      category = k
      category = taxon_rank_level_categories( k ) if key == "taxon_rank_level"
      category = taxon_observations_count_categories( k ) if key == "taxon_observations_count"
      counts[category][:correct].concat( v[:correct] )
      counts[category][:uncertain].concat( v[:uncertain] )
      counts[category][:incorrect].concat( v[:incorrect] )
    end
    data = {}
    counts.each do | k, v |
      data[k] = normalize_counts( v )
    end
    data
  end

  def group_precision_counts( ungrouped_counts, key )
    counts = Hash.new {| h, k | h[k] = [] }
    ungrouped_counts.reverse_each do | k, v |
      category = k
      category = taxon_rank_level_categories( k ) if key == "taxon_rank_level"
      category = taxon_observations_count_categories( k ) if key == "taxon_observations_count"
      counts[category].concat( v )
      counts[category].concat( v )
      counts[category].concat( v )
    end
    data = {}
    counts.each do | k, descendant_counts |
      data[k] = if descendant_counts.empty?
        0
      else
        descendant_counts.
          map {| descendant_count | calculate_precision( descendant_count ) }.sum / descendant_counts.count
      end
    end
    data
  end

  def get_stats_for_single_bar( key: "quality_grade", value: "research", raw: false, subset: nil )
    value_condition = value == "none" ? "#{key} IS NULL" : "#{key} = ?"

    value_condition = [subset, value_condition].compact.join( " AND " ) unless key == "quality_grade"

    counts = {
      incorrect: observation_accuracy_samples.where( "#{value_condition} AND correct = 0", value ).
        map( &:observation_id ),
      uncertain: observation_accuracy_samples.
        where( "#{value_condition} AND ( correct IS NULL OR correct = -1 )", value ).
        map( &:observation_id ),
      correct: observation_accuracy_samples.where( "#{value_condition} AND correct = 1", value ).
        map( &:observation_id )
    }
    return counts if raw

    normalize_counts( counts )
  end

  def get_barplot_data( the_key, subset )
    subset_filter = case subset
    when "verifiable_results" then "( quality_grade = 'research' OR quality_grade = 'needs_id' )"
    when "all_results" then nil
    else "quality_grade = 'research'"
    end

    thevals = observation_accuracy_samples.where( subset_filter ).map( &the_key.to_sym ).map do | val |
      if val.nil?
        ["taxon_observations_count", "year", "taxon_rank_level"].include?( the_key ) ? 0 : "none"
      else
        val
      end
    end.uniq.sort
    data = {}
    thevals.each do | the_val |
      data[the_val] = if ["taxon_observations_count", "taxon_rank_level"].include? the_key
        get_stats_for_single_bar( key: the_key, value: the_val, raw: true, subset: subset_filter )
      else
        get_stats_for_single_bar( key: the_key, value: the_val, subset: subset_filter )
      end
    end
    data = group_counts( data, the_key ) if ["taxon_observations_count", "taxon_rank_level"].include? the_key
    data
  end

  def get_precision_stats_for_single_bar( key: "quality_grade", value: "research", raw: false, subset: nil )
    value_condition = value == "none" ? "#{key} IS NULL" : "#{key} = ?"

    value_condition = [subset, value_condition].compact.join( " AND " ) unless key == "quality_grade"

    descendant_counts = observation_accuracy_samples.where( value_condition, value.to_s ).
      map( &:descendant_count )
    return descendant_counts if raw

    if descendant_counts.empty?
      0
    else
      descendant_counts.
        map {| descendant_count | calculate_precision( descendant_count ) }.sum / descendant_counts.count
    end
  end

  def get_precision_barplot_data( the_key, subset )
    subset_filter = case subset
    when "verifiable_results" then "( quality_grade = 'research' OR quality_grade = 'needs_id' )"
    when "all_results" then nil
    else "quality_grade = 'research'"
    end

    thevals = observation_accuracy_samples.where( subset_filter ).map( &the_key.to_sym ).map do | val |
      if val.nil?
        ["taxon_observations_count", "year", "taxon_rank_level"].include?( the_key ) ? 0 : "none"
      else
        val
      end
    end.uniq.sort
    data = {}
    thevals.each do | the_val |
      data[the_val] = if ["taxon_observations_count", "taxon_rank_level"].include? the_key
        get_precision_stats_for_single_bar( key: the_key, value: the_val, raw: true, subset: subset_filter )
      else
        get_precision_stats_for_single_bar( key: the_key, value: the_val, subset: subset_filter )
      end
    end
    data = group_precision_counts( data, the_key ) if ["taxon_observations_count", "taxon_rank_level"].include? the_key
    data
  end

  def format_validator_name( user_data )
    return user_data.last if user_data.second.nil? || user_data.second.gsub( "\n", "" ) == ""

    name_parts = user_data.second.split
    "#{name_parts.first[0].capitalize}. #{name_parts.last.capitalize}"
  end

  def get_validator_names( limit: 20, offset: 0 )
    validators_query = observation_accuracy_validators.where.not( validation_count: nil ).
      order( validation_count: :desc ).offset( offset )
    validators_query = validators_query.limit( limit ) unless limit.nil?

    user_ids = validators_query.map( &:user_id )
    users_data = User.where( id: user_ids ).pluck( :id, :name, :login )
    users = users_data.index_by( &:first )

    user_ids.map do | user_id |
      user_data = users[user_id]
      { name: format_validator_name( user_data ), id: user_id }
    end
  end
end
