# frozen_string_literal: true

class ObservationAccuracyExperiment < ApplicationRecord
  has_many :observation_accuracy_samples, dependent: :destroy
  has_many :observation_accuracy_validators, dependent: :destroy

  attribute :sample_size, :integer, default: 1_000
  attribute :validator_redundancy_factor, :integer, default: 10
  attribute :taxon_id, :integer

  after_create :generate_sample

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

  def sibling?( test_taxon, groundtruth_taxon )
    test_taxon_ancestor_ids = test_taxon.ancestor_ids
    test_taxon_ancestor_ids << test_taxon.id
    groundtruth_taxon_ancestor_ids = groundtruth_taxon.ancestor_ids
    groundtruth_taxon_ancestor_ids << groundtruth_taxon.id
    ( test_taxon_ancestor_ids - groundtruth_taxon_ancestor_ids ).count.positive? &&
      ( groundtruth_taxon_ancestor_ids - test_taxon.ancestor_ids ).count.positive?
  end

  def ancestor?( parent, child )
    parent_ancestor_ids = parent.ancestor_ids
    parent_ancestor_ids << parent.id
    child_ancestor_ids = child.ancestor_ids
    child_ancestor_ids << child.id
    ( parent_ancestor_ids - child_ancestor_ids ).count.zero? &&
      ( child_ancestor_ids - parent_ancestor_ids ).count.positive?
  end

  def assess_quality( test_taxon_id, groundtruth_taxon_id, disagreement )
    test_taxon = Taxon.find( test_taxon_id )
    groundtruth_taxon = Taxon.find( groundtruth_taxon_id )
    return 1 if test_taxon_id == groundtruth_taxon_id || ancestor?( test_taxon, groundtruth_taxon )

    return 0 if ( ancestor?( groundtruth_taxon, test_taxon ) &&
       disagreement ) || sibling?( test_taxon, groundtruth_taxon )

    nil
  end

  def get_quality_stats( qualities )
    qualities_low = qualities.map {| value | value[:quality].nil? ? 0 : value[:quality] }
    qualities_high = qualities.map {| value | value[:quality].nil? ? 1 : value[:quality] }
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

  def get_candidate_identifiers_by_taxon( observation_ids_grouped_by_taxon_id )
    root_id = Taxon.where( rank_level: Taxon::ROOT_LEVEL ).first.id
    identifiers_by_taxon_id = {}
    counter = 0
    denom = observation_ids_grouped_by_taxon_id.count
    observation_ids_grouped_by_taxon_id.each_key do | taxon_id |
      if taxon_id == root_id
        url = URI.parse( "https://stagingapi.inaturalist.org/v1/observations/identifiers?d1=2023-01-01" )
        http = Net::HTTP.new( url.host, url.port )
        http.use_ssl = true if url.scheme == "https"
        request = Net::HTTP::Get.new( "#{url.path}?#{url.query}" )
        response = http.request( request )
        result = JSON.parse( response.body )
        sorted_frequency_hash = result["results"][0..49].map {| r | [r["user_id"], r["count"]] }.to_h
      else
        url = URI.parse( "https://stagingapi.inaturalist.org/v1/observations/identifiers?taxon_id=#{taxon_id}" )
        http = Net::HTTP.new( url.host, url.port )
        http.use_ssl = true if url.scheme == "https"
        request = Net::HTTP::Get.new( "#{url.path}?#{url.query}" )
        response = http.request( request )
        result = JSON.parse( response.body )
        iders = result["results"].map {| r | r["user_id"] }
        ids = INatAPIService.get( "/identifications",
          { per_page: 200, taxon_id: taxon_id, category: "improving", d1: "2023-01-01", user_id: iders[0..49] } )
        if ids.results.empty?
          ids = INatAPIService.get( "/identifications",
            { per_page: 200, taxon_id: taxon_id, category: "improving", d1: "2023-01-01" } )
        end
        if ids.results.empty?
          ids = INatAPIService.get( "/identifications", { per_page: 200, taxon_id: taxon_id, category: "improving" } )
        end
        if ids.results.empty?
          ids = INatAPIService.get( "/identifications", { per_page: 200, taxon_id: taxon_id, category: "leading" } )
        end
        user_ids = ids.results.map {| r | r["user"]["id"] }
        frequency_hash = user_ids.group_by( &:itself ).transform_values( &:count )
        sorted_frequency_hash = frequency_hash.sort_by {| _, count | -count }.to_h
      end
      identifiers_by_taxon_id[taxon_id] = sorted_frequency_hash
      counter += 1
      if ( counter % 10 ).zero?
        puts "Processed #{counter} records of #{denom}"
      end
    end
    identifiers_by_taxon_id
  end

  def fetch_top_iders
    url = URI.parse( "https://stagingapi.inaturalist.org/v1/observations/identifiers?d1=2023-01-01" )
    http = Net::HTTP.new( url.host, url.port )
    http.use_ssl = true if url.scheme == "https"
    request = Net::HTTP::Get.new( "#{url.path}?#{url.query}" )
    response = http.request( request )
    result = JSON.parse( response.body )
    result["results"][0..499].map {| r | [r["user_id"], r["count"]] }.to_h
  end

  def associate_observations_with_identifiers( obs_ids_grouped_by_taxon_id, identifiers_by_taxon_id, top_iders )
    associations = Hash.new {| hash, key | hash[key] = [] }
    obs_ids_grouped_by_taxon_id.each do | taxon_id, obs_ids |
      sorted_identifiers = identifiers_by_taxon_id[taxon_id] || []
      user_obs_count = Hash.new( 0 )

      obs_ids.each do | obs_id |
        top_user_ids = start_with = sorted_identifiers.reject {| user_id, _ | user_obs_count[user_id] >= 100 }.
          select {| k, _ | top_iders.keys.include? k }.take( validator_redundancy_factor ).map( &:first )
        top_user_ids << sorted_identifiers.reject {| user_id, _ | user_obs_count[user_id] >= 100 }.
          take( validator_redundancy_factor - start_with.count ).
          map( &:first )
        top_user_ids = top_user_ids.flatten
        top_user_ids.each {| user_id | user_obs_count[user_id] += 1 }
        associations[obs_id] += top_user_ids
      end
    end
    associations.each_with_object( {} ) do | ( obs_id, user_ids ), result |
      user_ids.each do | user_id |
        result[user_id] ||= []
        result[user_id] << obs_id
      end
    end
  end

  def distribute_to_validators( obs_data )
    puts "Divide up the sample among identifiers"
    puts "with a validator redundancy factor of #{validator_redundancy_factor}..."
    observation_ids_grouped_by_taxon_id = obs_data.group_by {| observation | observation[:taxon_id] }.
      transform_values {| observations | observations.pluck( :observation_id ) }

    puts "Select identifiers for each taxon represented in the sample (this may take a while)..."
    identifiers_by_taxon_id = get_candidate_identifiers_by_taxon( observation_ids_grouped_by_taxon_id )

    puts "Fetch the top IDers..."
    top_iders = fetch_top_iders

    puts "Assign observations to identifiers..."
    obs_id_by_user = associate_observations_with_identifiers(
      observation_ids_grouped_by_taxon_id,
      identifiers_by_taxon_id,
      top_iders
    )

    obs_id_by_user.each do | user_id, observation_ids |
      observation_ids.each do | observation_id |
        ObservationAccuracyValidator.create!(
          observation_accuracy_experiment_id: id,
          user_id: user_id,
          observation_id: observation_id
        )
      end
    end
  end

  def generate_sample
    start_time = Time.now
    sample_size = self.sample_size
    taxon_id = self.taxon_id
    return nil if Observation.count.zero?

    puts "Generating sample of size #{sample_size}..."
    ceil = Observation.last.id
    random_numbers = ( 1..ceil ).to_a.sample( sample_size * 2 )
    o = if taxon_id.nil?
      Observation.select( :id ).where( "id IN (?)", random_numbers )
    else
      Observation.
        joins( :taxon ).select( "observations.id" ).
        where(
          "taxa.ancestry LIKE ( ? ) AND observations.id IN ( ? )",
          "#{Taxon.find( taxon_id ).ancestry}/%",
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
    root_id = Taxon.where( rank_level: Taxon::ROOT_LEVEL ).first.id
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
        descendant_count: taxon_descendant_count[obs.taxon_id]
      }
    end

    ObservationAccuracySample.create!( obs_data )

    distribute_to_validators( obs_data )

    self.sample_generation_date = Time.now
    save!

    end_time = Time.now
    duration = end_time - start_time
    puts "Sample generated in #{duration} seconds."
  end

  # this method replaces all validators with ones attributed to a single user for testing
  def replace_validators_for_testing( user_ids )
    o = ObservationAccuracySample.
      where( observation_accuracy_experiment_id: id ).
      limit( 200 ).
      pluck( :observation_id )
    return nil if o.count.zero?

    ObservationAccuracyValidator.where( observation_accuracy_experiment_id: id ).destroy_all
    user_ids.each do | user_id |
      o.each do | oid |
        oav = ObservationAccuracyValidator.new(
          observation_accuracy_experiment_id: id,
          user_id: user_id,
          observation_id: oid
        )
        oav.save!
      end
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

    number_of_validators = ObservationAccuracyValidator.where( observation_accuracy_experiment_id: id ).
      distinct.
      count( :user_id )
    puts "Distributed to #{number_of_validators} validators"
    puts "with a validator redundancy factor of #{validator_redundancy_factor}"

    unless validator_contact_date.nil?
      puts "Validators contacted on #{validator_contact_date} with a deadline of #{validator_deadline_date}"
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

  def contact_validators( validator_deadline_date )
    observation_accuracy_validators = ObservationAccuracyValidator.
      where( observation_accuracy_experiment_id: id )
    return nil if observation_accuracy_validators.empty?

    obs_id_by_user = {}
    observation_accuracy_validators.each do | observation_accuracy_validator |
      user_id = observation_accuracy_validator.user_id
      observation_id = observation_accuracy_validator.observation_id
      obs_id_by_user[user_id] ||= []
      obs_id_by_user[user_id] << observation_id
    end
    obs_id_by_user.each do | user_id, obs_ids |
      url = "https://www.inaturalist.org/observations/identify?" \
        "reviewed=any&quality_grade=needs_id%2Cresearch%2Ccasual&id=#{obs_ids.join( ',' )}"
      user = User.find( user_id )
      email_text = "
      Dear #{user.login},
      Can you please ID thes by #{validator_deadline_date}
      #{url}
      "
      puts email_text
    end
    self.validator_contact_date = Time.now
    self.validator_deadline_date = validator_deadline_date
    save!
  end

  def assess_experiment
    samples = ObservationAccuracySample.
      where( observation_accuracy_experiment_id: id )
    return nil if samples.empty?

    obs_data = []
    samples.each do | sample |
      obs_data << {
        observation_id: sample.observation_id,
        taxon_id: sample.taxon_id,
        quality_grade: sample.quality_grade,
        year: sample.year,
        iconic_taxon_name: sample.iconic_taxon_name,
        continent: sample.continent,
        taxon_observations_count: sample.taxon_observations_count,
        taxon_rank_level: sample.taxon_rank_level,
        descendant_count: sample.descendant_count
      }
    end
    observation_accuracy_validators = ObservationAccuracyValidator.
      where( observation_accuracy_experiment_id: id )
    obs_id_by_user = {}
    observation_accuracy_validators.each do | observation_accuracy_validator |
      user_id = observation_accuracy_validator.user_id
      observation_id = observation_accuracy_validator.observation_id
      obs_id_by_user[user_id] ||= []
      obs_id_by_user[user_id] << observation_id
    end

    groundtruths = {}
    obs_id_by_user.each do | user_id, oids |
      groundtruth_taxa = Identification.
        select( "DISTINCT ON ( observation_id ) observation_id, taxon_id, disagreement" ).
        where( observation_id: oids, user_id: user_id, current: true ).
        order( "observation_id DESC, created_at DESC" ).
        pluck( :observation_id, :taxon_id, :disagreement ).
        group_by( &:shift ).
        transform_values {| values | values.map {| v | { taxon_id: v[0], disagreement: v[1] } } }
      groundtruths[user_id] = groundtruth_taxa
    end

    responding_validators = groundtruths.keys.count
    validated_observations = groundtruths.values.map( &:keys ).flatten.uniq.count

    qualities = []
    obs_data.each do | obs |
      oid = obs[:observation_id].to_i
      test_taxon = obs[:taxon_id].to_i
      matches = groundtruths.values.map {| groundtruth_taxa | groundtruth_taxa[oid] }.compact.flatten
      if matches.empty?
        qualities << { observation_id: oid, quality: nil }
      else
        qualities_for_row = []
        matches.each do | match |
          groundtruth_taxon = match[:taxon_id]
          disagreement = match[:disagreement]
          quality = assess_quality( test_taxon, groundtruth_taxon, disagreement )
          qualities_for_row << { observation_id: oid, quality: quality }
        end
        qualities << if !qualities_for_row.map {| q | q[:quality].nil? }.all? &&
            qualities_for_row.map {| q | q[:quality] }.compact.uniq.count > 1
          # conflict
          { observation_id: oid, quality: -1 }
        else
          qualities_for_row[0]
        end
      end
    end

    if qualities.select {| q | q[:quality] == -1 }.count.positive?
      obs_ids = qualities.select {| q | q[:quality] == -1 }.map {| q | q[:observation_id] }.join( "," )
      puts "There is at least one conflict"
      puts "https://www.inaturalist.org/observations/identify?" \
        "reviewed=any&quality_grade=needs_id%2Cresearch%2Ccasual&id=#{obs_ids} )"
    else
      quality_stats = get_quality_stats( qualities )
      precisions = obs_data.map do | o |
        {
          id: o[:observation_id].to_i,
          precision: 1 / ( o[:descendant_count].to_i.zero? ? 1 : o[:descendant_count] ).to_f
        }
      end
      precision_vals = precisions.map {| o | o[:precision] }
      precision_stats = get_precisions_stats( precision_vals )
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
  end
end
