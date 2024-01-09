# frozen_string_literal: true

class ObservationAccuracyExperiment < ApplicationRecord
  has_many :observation_accuracy_samples, dependent: :destroy
  has_many :observation_accuracy_validators, dependent: :destroy

  attribute :sample_size, :integer, default: 1_000
  attribute :validator_redundancy_factor, :integer, default: 10

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
    return 1 if test_taxon_id == groundtruth_taxon_id || is_ancestor( test_taxon, groundtruth_taxon )

    return 0 if ( is_ancestor( groundtruth_taxon, test_taxon ) &&
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
    puts "#{mean_low.round( 4 )} +/- #{stdev_low.round( 4 )}"
    puts "#{mean_high.round( 4 )} +/- #{stdev_high.round( 4 )}"
    [mean_low, var_low, mean_high, var_high]
  end

  def get_precisions_stats( precisions )
    mean_precision = precisions.sum / precisions.count.to_f
    var_precision = bootstrap_variance( precisions )
    stdev_precision = Math.sqrt( var_precision )
    puts "#{mean_precision.round( 4 )} +/- #{stdev_precision.round( 4 )}"
    [mean_precision, var_precision]
  end

  def get_candidate_identifiers_by_taxon( observation_ids_grouped_by_taxon_id )
    root_id = Taxon.where( rank_level: Taxon::ROOT_LEVEL ).first.id
    identifiers_by_taxon_id = {}
    counter = 0
    denom = observation_ids_grouped_by_taxon_id.count
    observation_ids_grouped_by_taxon_id.each_key do | taxon_id |
      if taxon_id.nil? || taxon_id == root_id
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
    return nil if Observation.count.zero?

    puts "Generating sample of size #{sample_size}..."
    ceil = Observation.last.id
    random_numbers = ( 1..ceil ).to_a.sample( sample_size * 2 )
    o = Observation.select( :id ).where( "id IN (?)", random_numbers )
    o = o.map {| a | a[:id] }.shuffle[0..( sample_size - 1 )]
    observations = Observation.includes( :taxon ).find( o )
    puts "\t"

    puts "Generating taxonomic rank groupings..."
    rank_level_obs = {}
    obs_count_obs = {}
    observations.each do | observation |
      taxon = observation.taxon
      observation_id = observation.id
      taxon_rank_level = taxon&.rank_level
      rank_level_obs[observation_id] = taxon_rank_level
      taxon_observations_count = taxon&.observations_count
      obs_count_obs[observation_id] = taxon_observations_count
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

    puts "Generating obs count groupings..."
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

    puts "Generating obs quality groupings..."
    quality_frequencies = observations.group_by( &:quality_grade ).transform_values( &:count )
    sorted_quality_frequencies = quality_frequencies.sort_by {| _, count | -count }.to_h
    puts sorted_quality_frequencies.map {| k, v | "#{k}: #{v}" }.join( ", " )
    puts "\t"

    puts "Generating iconic taxa groupings..."
    iconic_taxon_key = Taxon::ICONIC_TAXA.map {| t | [t.id, t.name] }.to_h
    iconic_taxon_frequencies = observations.group_by {| obs | iconic_taxon_key[obs.iconic_taxon_id] }.
      transform_values( &:count )
    sorted_iconic_taxon_frequencies = iconic_taxon_frequencies.sort_by {| _, count | -count }.to_h
    puts sorted_iconic_taxon_frequencies.map {| k, v | "#{k}: #{v}" }.join( ", " )
    puts "\t"

    puts "Generating year groupings"
    year_frequencies = observations.group_by {| obs | obs.created_at.year }.transform_values( &:count )
    sorted_year_frequencies = year_frequencies.sort_by {| _, count | -count }.to_h
    puts sorted_year_frequencies.map {| k, v | "#{k}: #{v}" }.join( ", " )
    puts "\t"

    puts "Generating continent groupings"
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
    continent_frequencies = continent_obs.group_by {| _, continent | continent_key[continent] }.
      transform_values( &:count )
    sorted_continent_frequencies = continent_frequencies.sort_by {| _, count | -count }.to_h
    puts sorted_continent_frequencies.map {| k, v | "#{k}: #{v}" }.join( ", " )
    puts "\t"

    puts "Calculating number of descendants"
    root_id = Taxon.where( rank_level: Taxon::ROOT_LEVEL ).first.id
    taxon_descendant_count = {}
    observations.pluck( :taxon_id ).uniq.each do | taxon_id |
      taxon_id = root_id if taxon_id.nil?
      parent = Taxon.find( taxon_id )
      if parent.rank_level <= 10
        leaf_descendants = 1
      else
        parent_ancestry = if taxon_id == root_id
          taxon_id.to_s
        else
          "#{parent.ancestry} / #{parent.id}"
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
      taxon_descendant_count[taxon_id] = ( leaf_descendants.zero? ? 1 : leaf_descendants )
    end

    obs_data = observations.map do | obs |
      {
        observation_accuracy_experiment_id: id,
        observation_id: obs.id,
        taxon_id: obs.taxon_id,
        quality_grade: obs.quality_grade,
        year: obs.created_at.year,
        iconic_taxon_name: iconic_taxon_key[obs.iconic_taxon_id],
        continent: continent_key[continent_obs[obs.id]],
        taxon_observations_count: obs.taxon&.observations_count,
        taxon_rank_level: obs.taxon&.rank_level,
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
      groundtruth_taxa = Identification.select( "observation_id, taxon_id, disagreement" ).
        where( observation_id: oids, user_id: user_id, current: true ).
        group( :observation_id, :taxon_id, :disagreement ).
        map {| i | [i.observation_id, { taxon_id: i.taxon_id, disagreement: i.disagreement }] }.to_h
      groundtruths[user_id] = groundtruth_taxa
    end

    qualities = []
    obs_data.each do | obs |
      oid = obs[:id].to_i
      puts oid
      test_taxon = obs[:taxon_id].to_i
      matches = groundtruths.values.map {| groundtruth_taxa | groundtruth_taxa[oid] }.compact
      if matches.empty?
        qualities << { id: oid, quality: nil }
      else
        qualities_for_row = []
        matches.each do | match |
          groundtruth_taxon = match[:taxon_id]
          disagreement = match[:disagreement]
          quality = assess_quality( test_taxon, groundtruth_taxon, disagreement )
          qualities_for_row << { id: oid, quality: quality }
        end
        qualities << if !qualities_for_row.map {| q | q[:quality].nil? }.all? &&
            qualities_for_row.map {| q | q[:quality] }.compact.uniq.count > 1
          # conflict
          { id: oid, quality: -1 }
        else
          qualities_for_row[0]
        end
      end
    end

    if qualities.select {| q | q[:quality] == -1 }.count.positive?
      obs_ids = qualities.select {| q | q[:quality] == -1 }.map {| a | a[:id] }.join( "," )
      puts "There is at least one conflict"
      puts "https://www.inaturalist.org/observations/identify?" \
        "reviewed=any&quality_grade=needs_id%2Cresearch%2Ccasual&id=#{obs_ids} )"
    else
      subset = obs_data.select {| o | o[:continent] == "North America" }.map {| o | o[:id].to_i }
      quality_stats = get_quality_stats( qualities.select {| o | subset.include? o[:id] } )
      precisions = obs_data.map do | o |
        {
          id: o[:id].to_i,
          precision: 1 / ( o[:descendant_count].to_i.zero? ? 1 : o[:descendant_count] ).to_f
        }
      end
      precision_vals = precisions.select {| o | subset.include? o[:id] }.map {| o | o[:precision] }
      precision_stats = get_precisions_stats( precision_vals )
      self.assessment_date = Time.now
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
