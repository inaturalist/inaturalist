module MakeHelpers
  def make_annotation( options = {} )
    attribute = ControlledTerm.make!
    value = ControlledTerm.make!( is_value: true )  
    attribute.controlled_term_values << ControlledTermValue.new(
      controlled_attribute: attribute,
      controlled_value: value
    )
    Annotation.make( options.merge(
      controlled_attribute: attribute,
      controlled_value: value  
    ) )
  end

  def make_curator(opts = {})
    make_user_with_role(:curator, opts)
  end
  
  def make_admin
    make_user_with_role(User::JEDI_MASTER_ROLE)
  end
  
  def make_user_with_role(role_name, opts = {})
    user = User.make!(opts)
    user.roles << Role.make!(:name => role_name.to_s)
    user
  end
  
  def make_life_list_for_taxon(taxon, options = {})
    list = LifeList.make!(options)
    list.rules << ListRule.new(
      :operand => taxon, 
      :operator => 'in_taxon?'
    )
    list
  end
  
  def make_observation_of_threatened(options = {})
    Observation.make!(options.merge(
      :latitude => 38.333, :longitude => -122.111,
      :taxon => make_threatened_taxon,
      :created_at => Time.now.to_date
    ))
  end
  
  # It's important that the lat & lon don't show up in the date when doing 
  # simple regex tests
  def make_private_observation(options = {})
    Observation.make!(options.merge(
      :latitude => 38.888, :longitude => -122.222, 
      :geoprivacy => Observation::PRIVATE, 
      :created_at => Time.now.to_date
    ))
  end
  
  def make_research_grade_observation(options = {})
    options = {
      :taxon => Taxon.make!(:species), :latitude => 1, :longitude => 1, :observed_on_string => "yesterday"
    }.merge(options)
    o = Observation.make!(options)
    i = Identification.make!(:observation => o, :taxon => o.taxon)
    o.photos << LocalPhoto.make!(:user => o.user)
    Observation.set_quality_grade(o.id)
    o.reload
    o
  end

  def make_research_grade_candidate_observation(options = {})
    options = {
      :latitude => 1, :longitude => 1, :observed_on_string => "yesterday"
    }.merge(options)
    o = Observation.make!(options)
    o.photos << LocalPhoto.make!(:user => o.user)
    Observation.set_quality_grade(o.id)
    o.reload
    o
  end

  def make_mobile_observation(options = {})
    options = {
      :user_agent => "iNaturalist/2.3.0 (iOS iPhone OS 7.0.4 iPhone)"
    }.merge(options) 
    Observation.make!(options)
  end
  
  def make_local_photo(options = {})
    lp = LocalPhoto.make!(options)
    lp.observations << Observation.make!(:user => lp.user)
    lp
  end
  
  def make_project_invitation(options = {})
    pu = ProjectUser.make!
    o = Observation.make!
    pi = ProjectInvitation.create!(options.merge(:user => pu.user, :project => pu.project, :observation => o))
    pi
  end

  def make_project_observation(options = {})
    p = options[:project] || Project.make!
    t = options.delete(:taxon)
    u = options.delete(:user) || User.make!
    pu = p.project_users.where(user_id: u).first
    pu ||= ProjectUser.make!(:project => p, :user => u)
    o = Observation.make!(:user => u, :taxon => t)
    ProjectObservation.make!({:project => pu.project, :observation => o, :user => o.user}.merge(options))
  end
  
  def make_project_observation_from_research_quality_observation(options = {})
    p = options[:project] || Project.make!
    t = options.delete(:taxon)
    u = options.delete(:user) || User.make!
    pu = p.project_users.where(user_id: u).first
    pu ||= ProjectUser.make!(:project => p, :user => u)
    o = make_research_grade_observation(:user => u, :taxon => t)
    ProjectObservation.make!({:project => pu.project, :observation => o, :user => o.user}.merge(options))
  end
  
  def make_place_with_geom(options = {})
    wkt = options.delete(:wkt) || options.delete(:ewkt) || "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))"
    place = Place.make!(options)
    place.save_geom(GeoRuby::SimpleFeatures::Geometry.from_ewkt(wkt))
    place
  end

  def make_taxon_range_with_geom(options = {})
    wkt = options.delete(:wkt) || options.delete(:ewkt) || "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))"
    tr = TaxonRange.make!(options.merge(:geom => wkt))
    tr
  end

  def make_message(options = {})
    m = Message.make(options)
    m.user ||= m.to_user
    m.save!
    m
  end

  def make_taxon_swap( options = {} )
    input_taxon = options.delete(:input_taxon) || Taxon.make!( rank: Taxon::SPECIES )
    output_taxon = options.delete(:output_taxon) || Taxon.make!( rank: Taxon::SPECIES )
    validate = options.delete(:validate)
    swap = TaxonSwap.make( options )
    swap.add_input_taxon( input_taxon )
    swap.add_output_taxon( output_taxon )
    swap.save( validate: ( validate === false ? false : true ) )
    swap
  end

  def make_taxon_split( options = {} )
    input_taxon = options.delete(:input_taxon) || Taxon.make!( rank: Taxon::SPECIES )
    output_taxa = options.delete(:output_taxa) || [
      Taxon.make!( rank: Taxon::SPECIES ),
      Taxon.make!( rank: Taxon::SPECIES )
    ]
    split = TaxonSplit.make( options )
    split.add_input_taxon( input_taxon )
    output_taxa.each do |t|
      split.add_output_taxon( t )
    end
    split.save!
    split
  end

  def make_published_guide(options = {})
    g = Guide.make!(options)
    3.times { GuideTaxon.make!(:guide => g) }
    g.update_attributes(:published_at => Time.now)
    g
  end

  def make_threatened_taxon(options = {})
    options[:rank] ||= Taxon::SPECIES
    t = Taxon.make!(options)
    without_delay { ConservationStatus.make!(taxon: t, iucn: Taxon::IUCN_ENDANGERED) }
    t.reload
    t
  end
  
  # creating the tree is a bit tricky
  #
  # Life
  # |--- Animalia (iconic)
  # |    `--- Chordata
  # |         |--- Amphibia (iconic)
  # |         |    `--- Hylidae
  # |         |         `--- Pseudacris
  # |         |              `--- Pseudacris regilla
  # |         `--- Aves (iconic)
  # |              `--- Apodiformes
  # |                   `--- Trochilidae
  # |                        `--- Calypte
  # |                             `--- Calypte anna
  # `--- Plantae
  #      `--- Magnoliophyta
  #           `--- Magnoliopsida
  def load_test_taxa
    Rails.logger.debug "\n\n\n[DEBUG] loading test taxa"
    @Life = Taxon.find_by_name( "Life" ) || Taxon.make!( name: 'Life', rank: "state of matter" )
    
    set_taxon_with_rank_and_parent( "Animalia", Taxon::KINGDOM, @Life, is_iconic: true )
    set_taxon_with_rank_and_parent( "Chordata", Taxon::PHYLUM, @Animalia )
    set_taxon_with_rank_and_parent( "Amphibia", Taxon::CLASS, @Chordata, is_iconic: true )
    set_taxon_with_rank_and_parent( "Anura", Taxon::ORDER, @Amphibia )
    set_taxon_with_rank_and_parent( "Hylidae", Taxon::FAMILY, @Anura )
    set_taxon_with_rank_and_parent( "Pseudacris", Taxon::GENUS, @Hylidae )
    set_taxon_with_rank_and_parent( "Pseudacris regilla", Taxon::SPECIES, @Pseudacris )

    set_taxon_with_rank_and_parent( "Aves", Taxon::CLASS, @Chordata, is_iconic: true )
    set_taxon_with_rank_and_parent( "Apodiformes", Taxon::ORDER, @Aves )
    set_taxon_with_rank_and_parent( "Trochilidae", Taxon::FAMILY, @Apodiformes )
    set_taxon_with_rank_and_parent( "Calypte", Taxon::GENUS, @Trochilidae )
    set_taxon_with_rank_and_parent( "Calypte anna", Taxon::SPECIES, @Calypte, common_name: "Anna's Hummingbird" )
    
    set_taxon_with_rank_and_parent( "Plantae", Taxon::KINGDOM, @Life, is_iconic: true )
    set_taxon_with_rank_and_parent( "Magnoliophyta", Taxon::PHYLUM, @Plantae )
    set_taxon_with_rank_and_parent( "Magnoliopsida", Taxon::CLASS, @Magnoliophyta )
    set_taxon_with_rank_and_parent( "Myrtales", Taxon::ORDER, @Magnoliopsida )
    set_taxon_with_rank_and_parent( "Onagraceae", Taxon::FAMILY, @Myrtales )
    set_taxon_with_rank_and_parent( "Clarkia", Taxon::GENUS, @Onagraceae )
    set_taxon_with_rank_and_parent( "Clarkia amoena", Taxon::GENUS, @Clarkia )

    Taxon.reset_iconic_taxa_constants_for_tests

    Rails.logger.debug "[DEBUG] DONE loading test taxa\n\n\n"
  end

  def set_taxon_with_rank_and_parent( name, rank, parent, options = { } )
    varname = name.gsub( /\s+/, "_" )
    common_name = options.delete( :common_name )
    if existing_in_memory = instance_variable_get( "@#{varname}" )
      return existing_in_memory
    end
    if existing_in_db = Taxon.find_by_name( name )
      instance_variable_set( "@#{varname}", existing_in_db )
      return instance_variable_get( "@#{varname}" )
    end
    instance_variable_set( "@#{varname}", Taxon.make!( options.merge( name: name, rank: rank ) ) )
    instance_variable_get( "@#{varname}" ).update_attributes( parent: parent )
    if common_name
      instance_variable_get( "@#{varname}" ).taxon_names << TaxonName.make!(
        name: common_name, 
        taxon: instance_variable_get( "@#{varname}" ),
        lexicon: TaxonName::LEXICONS[:ENGLISH]
      )
    end
    instance_variable_get( "@#{varname}" )
  end

  def make_check_listed_taxon( options = {} )
    list = CheckList.make!( place: options[:place] || Place.make! )
    list.add_taxon( options[:taxon] || Taxon.make! )
  end

  def make_atlas_with_presence( options = { } )
    taxon = options[:taxon]
    presence_place = options.delete(:place) || make_place_with_geom( place_type: Place::COUNTRY, admin_level: Place::COUNTRY_LEVEL )
    listed_taxon = presence_place.check_list.add_taxon( taxon )
    AncestryDenormalizer.denormalize
    PlaceDenormalizer.denormalize
    Atlas.make!( options )
  end

  def make_observation_photo( options = { } )
    options[:observation] ||= Observation.make!
    options[:photo] ||= LocalPhoto.make!
    options[:photo].update_attributes( user: options[:observation].user )
    ObservationPhoto.make!( options )
  end
end
