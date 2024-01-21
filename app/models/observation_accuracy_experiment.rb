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

  def bootstrap_variance( original_sample )
    num_iterations = 1000
    bootstrap_means = []
    num_iterations.times do
      bootstrap_sample = Array.new( original_sample.size ) { original_sample.sample }
      bootstrap_mean = bootstrap_sample.sum / bootstrap_sample.size.to_f
      bootstrap_means << bootstrap_mean
    end
    mean_of_bootstrap_means = bootstrap_means.sum / bootstrap_means.size.to_f
    sum_squared_diff = bootstrap_means.map {| mean | ( mean - mean_of_bootstrap_means )**2 }.sum
    sum_squared_diff / ( bootstrap_means.size - 1 ).to_f
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

  def get_quality_stats( qualities )
    qualities_low = qualities.map {| q | q.nil? || q == -1 ? 0 : q }
    qualities_high = qualities.map {| q | q.nil? || q == -1 ? 1 : q }
    mean_high = qualities_high.sum / qualities_high.count.to_f
    mean_low = qualities_low.sum / qualities_low.count.to_f
    var_high = bootstrap_variance( qualities_high )
    stdev_high = Math.sqrt( var_high )
    var_low = bootstrap_variance( qualities_low )
    stdev_low = Math.sqrt( var_low )
    puts "Accuracy (lower): #{mean_low.round( 4 )} +/- #{stdev_low.round( 4 )}"
    puts "Accuracy (higher): #{mean_high.round( 4 )} +/- #{stdev_high.round( 4 )}"
    [mean_low, var_low, mean_high, var_high]
  end

  def get_precisions_stats( precisions )
    mean_precision = precisions.sum / precisions.count.to_f
    var_precision = bootstrap_variance( precisions )
    stdev_precision = Math.sqrt( var_precision )
    puts "Precision: #{mean_precision.round( 4 )} +/- #{stdev_precision.round( 4 )}"
    [mean_precision, var_precision]
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

  # this method replaces all validators with ones attributed to a single user for testing
  def replace_validators_for_testing( user_ids )
    o = observation_accuracy_samples.
      limit( 200 )
    return nil if o.count.zero?

    ObservationAccuracyValidator.where( observation_accuracy_experiment_id: id ).destroy_all

    user_ids.each do | user_id |
      observation_validator = ObservationAccuracyValidator.
        create( user_id: user_id, observation_accuracy_experiment_id: id )
      observation_validator.observation_accuracy_samples << o
    end
  end

  def generate_report
    samples = ObservationAccuracySample.
      where( observation_accuracy_experiment_id: id )
    return nil if samples.empty?

    puts "Sample consistes of #{samples.count} observations generated on #{sample_generation_date}"
    puts "restricted to #{Taxon.find( taxon_id ).name}" if taxon_id
    puts "\t"
    puts "Sample grouped by taxonomic rank:"
    rank_level_obs = {}
    obs_count_obs = {}
    samples.each do | sample |
      rank_level_obs[sample.observation_id] = sample.taxon_rank_level
      obs_count_obs[sample.observation_id] = sample.taxon_observations_count
    end
    rank_level_frequencies = rank_level_obs.group_by do | _, count |
      case count
      when 5
        "subspecies"
      when 10
        "species"
      when 11..20
        "genus"
      when 21..30
        "family"
      when 31..40
        "order"
      when 41..50
        "class"
      when 51..60
        "phylum"
      when 61..70
        "kingdom"
      else
        "life"
      end
    end.transform_values( &:count )
    bin_order = ["subspecies", "species", "genus", "family", "order", "class", "phylum", "kingdom", "life"]
    sorted_rank_level_frequencies = rank_level_frequencies.sort_by {| bin, _ | bin_order.index( bin ) }.to_h
    puts sorted_rank_level_frequencies.map {| k, v | "#{k}: #{v}" }.join( ", " )
    puts "\t"

    puts "Sample grouped by observation count:"
    obs_count_frequencies = obs_count_obs.group_by do | _, count |
      case count
      when 1..100
        "1-100"
      when 101..1_000
        "100-1000"
      when 1_001..10_000
        "1000-10000"
      when 10_001..100_000
        "10000-100000"
      else
        ">100000"
      end
    end.transform_values( &:count )
    bin_order = ["1-100", "100-1000", "1000-10000", "10000-100000", ">100000"]
    sorted_obs_count_frequencies = obs_count_frequencies.sort_by {| bin, _ | bin_order.index( bin ) }.to_h
    puts sorted_obs_count_frequencies.map {| k, v | "#{k}: #{v}" }.join( ", " )
    puts "\t"

    attributes_to_group_by = [:quality_grade, :iconic_taxon_name, :year, :continent]

    attributes_to_group_by.each do | attribute |
      puts "Sample grouped by #{attribute.to_s.humanize}:"
      frequencies = samples.group_by( &attribute ).transform_values( &:count )
      sorted_frequencies = frequencies.sort_by {| _, count | -count }.to_h
      puts sorted_frequencies.map {| k, v | "#{k}: #{v}" }.join( ", " )
      puts "\t"
    end

    number_of_validators = observation_accuracy_validators.count
    puts "Sample distributed among #{number_of_validators} candidate validator(s)"
    puts "with a validator redundancy factor of #{validator_redundancy_factor}"

    unless validator_contact_date.nil?
      puts "Candidate validators contacted on #{validator_contact_date} with a deadline of #{validator_deadline_date}"
    end

    return if assessment_date.nil?

    puts "Experiment assessed on #{assessment_date}"
    responding_validators_percent = ( responding_validators / number_of_validators.to_f ).round( 2 ) * 100
    puts "At that time #{responding_validators} validator(s) responded (#{responding_validators_percent}%)"
    validated_observations_percent = ( validated_observations / samples.count.to_f ).round( 2 ) * 100
    puts "and validated #{validated_observations} sample(s) (#{validated_observations_percent}%)"
    puts "\t"
    puts "Accuracy (lower): #{low_acuracy_mean.round( 4 )} +/- #{Math.sqrt( low_acuracy_variance ).round( 4 )}"
    puts "Accuracy (higher): #{high_accuracy_mean.round( 4 )} +/- #{Math.sqrt( high_accuracy_variance ).round( 4 )}"
    puts "Precision: #{precision_mean.round( 4 )} +/- #{Math.sqrt( precision_variance ).round( 4 )}"
  end

  def get_sample_id_by_validator
    sample_ids_by_validator_id = {}
    observation_accuracy_validators.each do | validator |
      sample_ids_by_validator_id[validator.id] = validator.observation_accuracy_samples.pluck( :id )
    end
    sample_ids_by_validator_id
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
    quality_stats = get_quality_stats( observation_accuracy_samples.map( &:correct ) )
    precision_stats = get_precisions_stats( observation_accuracy_samples.
      map {| sample | calculate_precision( sample.descendant_count ) } )
    self.assessment_date = Time.now
    self.responding_validators = responding_validators
    self.validated_observations = validated_observations
    self.low_acuracy_mean = quality_stats[0]
    self.low_acuracy_variance = quality_stats[1]
    self.high_accuracy_mean = quality_stats[2]
    self.high_accuracy_variance = quality_stats[3]
    self.precision_mean = precision_stats[0]
    self.precision_variance = precision_stats[1]
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

  def get_incorrect_observations_in_sample
    samples = ObservationAccuracySample.where( observation_accuracy_experiment_id: id, correct: 0 )
    return nil unless samples.count.positive?

    oids = samples.map( &:observation_id ).join( "," )
    FakeView.identify_observations_url(
      place_id: "any",
      reviewed: "any",
      quality_grade: "needs_id,research,casual",
      id: oids
    )
  end

  def get_stats_for_single_bar( key: "quality_grade", value: "research" )
    value_condition = value == "none" ? "#{key} IS NULL" : "#{key} = ?"
    counts = {
      incorrect: observation_accuracy_samples.where( "#{value_condition} AND correct = 0", value ).
        map( &:observation_id ),
      uncertain: observation_accuracy_samples.
        where( "#{value_condition} AND ( correct IS NULL OR correct = -1 )", value ).
        map( &:observation_id ),
      correct: observation_accuracy_samples.where( "#{value_condition} AND correct = 1", value ).
        map( &:observation_id )
    }
    total = counts.values.flatten.count
    stats = counts.transform_values do | ids |
      norm = ( total.zero? ? 0 : ids.count / total.to_f * 100 ).round( 2 )
      { url: FakeView.observations_url( verifiable: "any", place_id: "any", id: ids.join( "," ) ), height: norm }
    end
    [stats[:incorrect], stats[:uncertain], stats[:correct]]
  end

  def get_barplot_data( the_key )
    thevals = observation_accuracy_samples.map( &the_key.to_sym ).map {| val | val.nil? ? "none" : val }.uniq.sort
    data = {}
    thevals.each do | the_val |
      data[the_val] = get_stats_for_single_bar( key: the_key, value: the_val )
    end
    data
  end
end
