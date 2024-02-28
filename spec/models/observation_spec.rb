# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

describe Observation do
  before( :all ) do
    DatabaseCleaner.clean_with( :truncation, except: %w(spatial_ref_sys) )
  end

  elastic_models( Observation, Taxon )

  describe "species_guess parsing" do
    stub_elastic_index! Observation, Taxon

    let( :user ) { build :user }
    let( :observation ) { build :observation, taxon: nil, user: user, editing_user_id: user.id }

    it "should choose a taxon if the guess corresponds to a unique taxon" do
      taxon = create :taxon, :as_species
      observation.species_guess = taxon.name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq taxon.id
    end

    it "should not choose an inactive taxon" do
      taxon = create :taxon, :as_species, is_active: false
      observation.species_guess = taxon.name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to be_blank
    end

    it "should choose a taxon from species_guess if exact matches form a subtree" do
      taxon = create :taxon, :as_species, name: "Spirolobicus bananaensis"
      child = create :taxon, :as_subspecies, parent: taxon, name: "#{taxon.name} foo"
      common_name = "Spiraled Banana Shrew"
      create :taxon_name, taxon: taxon, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]
      create :taxon_name, taxon: child, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]

      observation.species_guess = common_name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq taxon.id
    end

    it "should not choose a taxon from species_guess if exact matches don't form a subtree" do
      ancestor1 = create :taxon, :as_genus
      ancestor2 = create :taxon, :as_genus
      taxon = create :taxon, :as_species, parent: ancestor1, name: "Spirolobicus bananaensis"
      child = create :taxon, :as_subspecies, parent: taxon, name: "#{taxon.name} foo"
      taxon2 = create :taxon, :as_species, parent: ancestor2
      common_name = "Spiraled Banana Shrew"
      create :taxon_name, taxon: taxon, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]
      create :taxon_name, taxon: child, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]
      create :taxon_name, taxon: taxon2, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]
      expect( child.ancestors ).to include( taxon )
      expect( child.ancestors ).not_to include( taxon2 )
      expect( Taxon.joins( :taxon_names ).where( "taxon_names.name = ?", common_name ).count ).to eq( 3 )

      observation.species_guess = common_name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to be_blank
    end

    it "should choose a taxon from species_guess if exact matches form a subtree regardless of case" do
      taxon = create :taxon, rank: "species", name: "Spirolobicus bananaensis"
      child = create :taxon, rank: "subspecies", parent: taxon, name: "#{taxon.name} foo"
      common_name = "Spiraled Banana Shrew"
      create :taxon_name, taxon: taxon, name: common_name.downcase, lexicon: TaxonName::LEXICONS[:ENGLISH]
      create :taxon_name, taxon: child, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]

      observation.species_guess = common_name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq taxon.id
    end

    it "should not make a guess for problematic names" do
      Taxon::PROBLEM_NAMES.each do | name |
        next unless build( :taxon, name: name.capitalize ).valid?

        observation = build :observation, species_guess: name
        expect { observation.set_taxon_from_species_guess }.to_not change( observation, :taxon_id )
      end
    end

    it "should choose a taxon from a parenthesized scientific name" do
      name = "Northern Pygmy Owl (Glaucidium gnoma)"
      t = create :taxon, name: "Glaucidium gnoma"

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq t.id
    end

    it "should choose a taxon from blah sp" do
      name = "Clarkia sp"
      t = create :taxon, name: "Clarkia"

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq t.id

      name = "Clarkia sp."

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq t.id
    end

    it "should choose a taxon from blah ssp" do
      name = "Clarkia ssp"
      t = create :taxon, name: "Clarkia"

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq t.id

      name = "Clarkia ssp."

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq t.id
    end

    it "should not make a guess if ends in a question mark" do
      t = create :taxon, name: "Foo bar"

      observation.species_guess = "#{t.name}?"
      observation.set_taxon_from_species_guess
      expect( observation.taxon ).to be_blank
    end
  end

  describe "named scopes" do
    before( :all ) do
      load_test_taxa
    end
    # Valid UTC is something like:
    # '2008-01-01T01:00:00+00:00'
    # '2008-11-30T18:53:15+00:00'
    before( :each ) do
      @after = 13.months.ago
      @before = 5.months.ago

      @after_formats = [@after, @after.iso8601]
      @before_formats = [@before, @before.iso8601]

      @amphibia = Taxon.find_by_name( "Amphibia" )
      @mollusca = Taxon.find_by_name( "Mollusca" )
      @pseudacris = Taxon.find_by_name( "Pseudacris regilla" )

      @pos = Observation.make!(
        taxon: @pseudacris,
        observed_on_string: "14 months ago",
        id_please: true,
        latitude: 20.01,
        longitude: 20.01,
        created_at: 14.months.ago,
        time_zone: "UTC"
      )

      @neg = Observation.make!(
        taxon: @pseudacris,
        observed_on_string: "yesterday at 1pm",
        latitude: 40,
        longitude: 40,
        time_zone: "UTC"
      )

      @between = Observation.make!(
        taxon: @pseudacris,
        observed_on_string: "6 months ago",
        created_at: 6.months.ago,
        time_zone: "UTC"
      )

      @aaron_saw_an_amphibian = Observation.make!( taxon: @pseudacris )
      @aaron_saw_a_mollusk = Observation.make!(
        taxon: @mollusca,
        observed_on_string: "6 months ago",
        created_at: 6.months.ago,
        time_zone: "UTC"
      )
      @aaron_saw_a_mystery = Observation.make!(
        observed_on_string: "6 months ago",
        created_at: 6.months.ago,
        time_zone: "UTC"
      )

      Observation.record_timestamps = false
      @pos.updated_at = 14.months.ago
      @pos.save

      @between.updated_at = 6.months.ago
      @between.save
      Observation.record_timestamps = true
    end

    it "should find observations in a bounding box" do
      obs = Observation.in_bounding_box( 20, 20, 30, 30 )
      expect( obs ).to include( @pos )
      expect( obs ).not_to include( @neg )
    end

    it "should find observations in a bounding box in a year" do
      pos = Observation.make!( latitude: @pos.latitude, longitude: @pos.longitude,
        observed_on_string: "2010-01-01" )
      neg = Observation.make!( latitude: @pos.latitude, longitude: @pos.longitude,
        observed_on_string: "2011-01-01" )
      observations = Observation.in_bounding_box( 20, 20, 30, 30 ).on( "2010" )
      expect( observations.map( &:id ) ).to include( pos.id )
      expect( observations.map( &:id ) ).not_to include( neg.id )
    end

    it "should find observations in a bounding box spanning the date line" do
      pos = Observation.make!( latitude: 0, longitude: 179 )
      neg = Observation.make!( latitude: 0, longitude: 170 )
      observations = Observation.in_bounding_box( -1, 178, 1, -178 )
      expect( observations.map( &:id ) ).to include( pos.id )
      expect( observations.map( &:id ) ).not_to include( neg.id )
    end

    it "should find observations using the shorter box method" do
      obs = Observation.near_point( 20, 20 ).all
      expect( obs ).to include( @pos )
      expect( obs ).not_to include( @neg )
    end

    it "should find observations with latitude and longitude" do
      obs = Observation.has_geo
      expect( obs ).to include( @pos, @neg )
      expect( obs ).not_to include( @between )
    end

    it "should find observations requesting identification" do
      pos = make_research_grade_candidate_observation
      expect( pos.quality_grade ).to eq Observation::NEEDS_ID
      observations = Observation.has_id_please
      expect( observations ).to include( pos )
      expect( observations ).not_to include( @neg )
    end

    describe "has_photos" do
      it "should find observations with photos" do
        make_observation_photo( observation: @pos )
        obs = Observation.has_photos.all
        expect( obs ).to include( @pos )
        expect( obs ).not_to include( @neg )
      end
    end

    it "should find observations observed after a certain time" do
      @after_formats.each do | format |
        obs = Observation.observed_after( format )
        expect( obs ).to include( @neg, @between )
        expect( obs ).not_to include( @pos )
      end
    end

    it "should find observations observed before a specific time" do
      @before_formats.each do | format |
        obs = Observation.observed_before( format )
        expect( obs ).to include( @pos, @between )
        expect( obs ).not_to include( @neg )
      end
    end

    it "should find observations observed between two time bounds" do
      @after_formats.each do | after_format |
        @before_formats.each do | before_format |
          obs = Observation.observed_after( after_format ).observed_before( before_format )
          expect( obs ).to include( @between )
          expect( obs ).not_to include( @pos, @neg )
        end
      end
    end

    it "should find observations created after a certain time" do
      @after_formats.each do | format |
        obs = Observation.created_after( format )
        expect( obs ).to include( @neg, @between )
        expect( obs ).not_to include( @pos )
      end
    end

    it "should find observations created before a specific time" do
      @before_formats.each do | format |
        obs = Observation.created_before( format )
        expect( obs ).to include( @pos, @between )
        expect( obs ).not_to include( @neg )
      end
    end

    it "should find observations created between two time bounds" do
      @after_formats.each do | after_format |
        @before_formats.each do | before_format |
          obs = Observation.created_after( after_format ).created_before( before_format )
          expect( obs ).to include( @between )
          expect( obs ).not_to include( @pos, @neg )
        end
      end
    end

    it "should find observations updated after a certain time" do
      @after_formats.each do | format |
        obs = Observation.updated_after( format )
        expect( obs ).to include( @neg, @between )
        expect( obs ).not_to include( @pos )
      end
    end

    it "should find observations updated before a specific time" do
      @before_formats.each do | format |
        obs = Observation.updated_before( format )
        expect( obs ).to include( @pos, @between )
        expect( obs ).not_to include( @neg )
      end
    end

    it "should find observations updated between two time bounds" do
      @after_formats.each do | after_format |
        @before_formats.each do | before_format |
          obs = Observation.updated_after( after_format ).updated_before( before_format )
          expect( obs ).to include( @between )
          expect( obs ).not_to include( @pos, @neg )
        end
      end
    end

    it "should find observations in one iconic taxon" do
      observations = Observation.has_iconic_taxa( @mollusca )
      expect( observations ).to include( @aaron_saw_a_mollusk )
      expect( observations.map( &:id ) ).not_to include( @aaron_saw_an_amphibian.id )
    end

    it "should find observations in many iconic taxa" do
      observations = Observation.has_iconic_taxa(
        [@mollusca, @amphibia]
      )
      expect( observations ).to include( @aaron_saw_a_mollusk )
      expect( observations ).to include( @aaron_saw_an_amphibian )
    end

    it "should find observations with NO iconic taxon" do
      observations = Observation.has_iconic_taxa(
        [@mollusca, nil]
      )
      expect( observations ).to include( @aaron_saw_a_mollusk )
      expect( observations ).to include( @aaron_saw_a_mystery )
    end

    it "should order observations by created_at" do
      last_obs = Observation.make!
      expect( Observation.order_by( "created_at" ).to_a.last ).to eq last_obs
    end

    it "should reverse order observations by created_at" do
      last_obs = Observation.make!
      expect( Observation.order_by( "created_at DESC" ).first ).to eq last_obs
    end

    it "should not find anything for a non-existant taxon ID" do
      expect( Observation.of( 91_919_191 ) ).to be_empty
    end

    it "should not bail on invalid dates" do
      expect do
        Observation.on( "2013-02-30" ).all
      end.not_to raise_error
    end

    it "scopes by reviewed_by" do
      o = Observation.make!
      u = User.make!
      ObservationReview.make!( observation: o, user: u )
      expect( Observation.reviewed_by( u ).first ).to eq o
    end

    it "scopes by not_reviewed_by" do
      Observation.make!
      u = User.make!
      expect( Observation.not_reviewed_by( u ).count ).to eq Observation.count
    end

    describe :in_projects do
      it "should find observations in a project by id" do
        po = make_project_observation
        other_o = Observation.make!
        expect( Observation.in_projects( po.project_id ) ).to include po.observation
        expect( Observation.in_projects( po.project_id ) ).not_to include other_o
      end
      it "should find observations in a project by slug" do
        po = make_project_observation
        other_o = Observation.make!
        expect( Observation.in_projects( po.project.slug ) ).to include po.observation
        expect( Observation.in_projects( po.project.slug ) ).not_to include other_o
      end
      it "should find observations in a project that begins with a number" do
        other_p = Project.make!
        po = make_project_observation(
          project: Project.make!( title: "#{other_p.id}MBC: Five Minute Bird Counts New Zealand" )
        )
        expect( po.project.slug.to_i ).to eq other_p.id
        other_o = Observation.make!
        expect( Observation.in_projects( po.project_id ) ).to include po.observation
        expect( Observation.in_projects( po.project_id ) ).not_to include other_o
      end
      it "should find observations in a project that begins with a number by slug" do
        other_p = Project.make!
        po = make_project_observation(
          project: Project.make!( title: "#{other_p.id}MBC: Five Minute Bird Counts New Zealand" )
        )
        expect( po.project.slug.to_i ).to eq other_p.id
        other_o = Observation.make!
        expect( Observation.in_projects( po.project.slug ) ).to include po.observation
        expect( Observation.in_projects( po.project.slug ) ).not_to include other_o
      end
    end

    describe :of do
      it "should find observations of a taxon" do
        t = without_delay { Taxon.make! }
        o = Observation.make!( taxon: t )
        expect( Observation.of( t ).first ).to eq o
      end
      it "should find observations of a descendant of a taxon" do
        t = without_delay { Taxon.make!( rank: Taxon::GENUS ) }
        c = without_delay { Taxon.make!( parent: t, rank: Taxon::SPECIES ) }
        o = Observation.make!( taxon: c )
        expect( Observation.of( t ).first ).to eq o
      end
    end

    describe :with_identifications_of do
      it "should include observations with identifications of the taxon" do
        i = Identification.make!
        o = Observation.make!
        expect( Observation.with_identifications_of( i.taxon ) ).to include i.observation
        expect( Observation.with_identifications_of( i.taxon ) ).not_to include o
      end
      it "should include observations with identifications of descendant taxa" do
        parent = Taxon.make!( rank: Taxon::GENUS )
        child = Taxon.make!( rank: Taxon::SPECIES, parent: parent )
        i = Identification.make!( taxon: child )
        expect( Observation.with_identifications_of( parent ) ).to include i.observation
      end
      it "should not return duplicate observations when there are multiple identifications" do
        o = Observation.make!
        i1 = Identification.make!( observation: o )
        Identification.make!( observation: o, taxon: i1.taxon )
        expect( Observation.with_identifications_of( i1.taxon ).count ).to eq 1
      end
    end
  end

  describe "query" do
    it "should filter by quality_grade" do
      o_needs_id = make_research_grade_candidate_observation
      o_needs_id.reload
      o_verified = make_research_grade_observation
      o_casual = Observation.make!
      expect( Observation.query( quality_grade: Observation::NEEDS_ID ) ).to include o_needs_id
      expect( Observation.query( quality_grade: Observation::NEEDS_ID ) ).not_to include o_verified
      expect( Observation.query( quality_grade: Observation::NEEDS_ID ) ).not_to include o_casual
      expect( Observation.query( quality_grade: Observation::RESEARCH_GRADE ) ).to include o_verified
      expect( Observation.query( quality_grade: Observation::CASUAL ) ).to include o_casual
    end

    it "should filter by research grade" do
      r = make_research_grade_observation
      c = Observation.make!( user: r.user )
      observations = Observation.query( user: r.user, quality_grade: Observation::RESEARCH_GRADE ).all
      expect( observations ).to include( r )
      expect( observations ).not_to include( c )
    end

    it "should filter by comma-separated quality grades" do
      r = make_research_grade_observation
      expect( r ).to be_research_grade
      n = make_research_grade_candidate_observation
      expect( n ).to be_needs_id
      u = Observation.make!( user: r.user )
      expect( u.quality_grade ).to eq Observation::CASUAL
      observations = Observation.query( user: r.user,
        quality_grade: "#{Observation::RESEARCH_GRADE},#{Observation::NEEDS_ID}" ).all
      expect( observations ).to include( r )
      expect( observations ).to include( n )
      expect( observations ).not_to include( u )
    end

    it "should filter by taxon_ids[] if there's only one taxon" do
      taxon = Taxon.make!
      obs_of_taxon = Observation.make!( taxon: taxon )
      obs_not_of_taxon = Observation.make!( taxon: Taxon.make! )
      observations = Observation.query( taxon_ids: [taxon.id] ).all
      expect( observations ).to include( obs_of_taxon )
      expect( observations ).not_to include( obs_not_of_taxon )
    end
    it "should filter by taxon_ids[] if all taxa are iconic" do
      load_test_taxa
      o1 = Observation.make!( taxon: @Aves )
      o2 = Observation.make!( taxon: @Amphibia )
      o3 = Observation.make!( taxon: @Animalia )
      expect( @Aves ).to be_is_iconic
      expect( @Amphibia ).to be_is_iconic
      expect( @Animalia ).to be_is_iconic
      observations = Observation.query( taxon_ids: [@Aves.id, @Amphibia.id] ).to_a
      expect( observations ).to include( o1 )
      expect( observations ).to include( o2 )
      expect( observations ).not_to include( o3 )
    end
  end

  describe "to_json" do
    it "should not include script tags" do
      o = build_stubbed :observation, description: "<script lang='javascript'>window.close()</script>"
      expect( o.to_json ).not_to match( /<script/ )
      expect( o.to_json( viewer: o.user,
        force_coordinate_visibility: true,
        include: [:user, :taxon, :iconic_taxon] ) ).not_to match( /<script/ )
      o = build_stubbed :observation, species_guess: "<script lang='javascript'>window.close()</script>"
      expect( o.to_json ).not_to match( /<script/ )
    end
  end

  describe "#set_license" do
    let!( :observation ) { create :observation }

    before { allow( observation ).to receive( :set_license ) }

    it "sets geom on save" do
      observation.run_callbacks :save

      expect( observation ).to have_received :set_license
    end
  end

  describe "license" do
    stub_elastic_index! Observation

    it "should use the user's default observation license" do
      o = build_stubbed :observation,
        license: nil,
        user: build_stubbed( :user, preferred_observation_license: "CC-BY-NC" )
      o.set_license
      expect( o.license ).to eq o.user.preferred_observation_license
    end

    it "should nilify if not a license" do
      o = build_stubbed :observation, license: Observation::CC_BY
      o.set_license
      expect( o.license ).to_not be_blank
      o.assign_attributes license: "on"
      o.set_license
      expect( o.license ).to be_blank
    end

    it "should normalize license" do
      o = build_stubbed :observation, license: "cc by Nc"
      o.set_license
      expect( o.license ).to eq Observation::CC_BY_NC
    end

    it "should update default license when requested" do
      u = create :user
      expect( u.preferred_observation_license ).to be_blank
      o = create :observation, user: u, make_license_default: true, license: Observation::CC_BY_NC
      expect( o.license ).to eq Observation::CC_BY_NC
      u.reload
      expect( u.preferred_observation_license ).to eq Observation::CC_BY_NC
    end

    it "should update all other observations when requested" do
      u = create :user
      o1 = create :observation, user: u, license: nil
      o2 = create :observation, user: u, license: nil
      expect( o1.license ).to be_blank
      o2.make_licenses_same = true
      o2.license = Observation::CC_BY_NC
      o2.save
      o1.reload
      expect( o1.license ).to eq Observation::CC_BY_NC
    end
  end

  describe "update_stats" do
    it "should not consider outdated identifications as agreements" do
      o = Observation.make!( taxon: Taxon.make!( rank: "species", name: "Species one" ) )
      old_ident = Identification.make!( observation: o, taxon: o.taxon )
      _new_ident = Identification.make!( observation: o, user: old_ident.user,
        taxon: Taxon.make!( rank: "species", name: "Species two" ) )
      o.reload
      o.update_stats
      o.reload
      old_ident.reload
      expect( old_ident ).not_to be_current
      expect( o.num_identification_agreements ).to eq( 0 )
      expect( o.num_identification_disagreements ).to eq( 1 )
    end
  end

  describe "update_stats_for_observations_of" do
    elastic_models( Identification )

    it "should work" do
      parent = Taxon.make!( rank: Taxon::GENUS )
      child = Taxon.make!( rank: Taxon::SPECIES )
      o = Observation.make!( taxon: parent )
      Identification.make!( observation: o, taxon: child )
      o.reload
      expect( o.num_identification_agreements ).to eq( 0 )
      expect( o.num_identification_disagreements ).to eq( 1 )
      child.update( parent: parent )
      Observation.update_stats_for_observations_of( parent )
      o.reload
      expect( o.num_identification_agreements ).to eq( 1 )
      expect( o.num_identification_disagreements ).to eq( 0 )
    end

    it "should work" do
      parent = Taxon.make!( rank: Taxon::GENUS )
      child = Taxon.make!( rank: Taxon::SPECIES )
      o = Observation.make!( taxon: parent )
      Identification.make!( observation: o, taxon: child )
      o.reload
      expect( o.community_taxon ).to be_blank
      child.update( parent: parent )
      Observation.update_stats_for_observations_of( parent )
      o.reload
      expect( o.community_taxon ).not_to be_blank
    end
  end

  describe "nested observation_field_values" do
    it "should create a new record if ID set but existing not found" do
      ofv = ObservationFieldValue.make!
      of = ofv.observation_field
      o = ofv.observation
      attrs = {
        "observation_field_values_attributes" => {
          "0" => {
            "_destroy" => "false",
            "observation_field_id" => ofv.observation_field_id,
            "value" => ofv.value,
            "id" => ofv.id
          }
        }
      }
      ofv.destroy
      expect { o.update( attrs ) }.not_to raise_error
      o.reload
      expect( o.observation_field_values.last.observation_field_id ).to eq( of.id )
    end

    it "should remove records if ID set but existing not found" do
      ofv = ObservationFieldValue.make!
      ofv.observation_field
      o = ofv.observation
      attrs = {
        "observation_field_values_attributes" => {
          "0" => {
            "_destroy" => "true",
            "observation_field_id" => ofv.observation_field_id,
            "value" => ofv.value,
            "id" => ofv.id
          }
        }
      }
      ofv.destroy
      expect { o.update( attrs ) }.not_to raise_error
      o.reload
      expect( o.observation_field_values ).to be_blank
    end
  end

  describe "taxon updates" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "should generate an update" do
      t = Taxon.make!
      s = Subscription.make!( resource: t )
      o = Observation.make( taxon: t )
      expect( UpdateAction.unviewed_by_user_from_query( s.user_id, resource: t ) ).to eq false
      without_delay do
        o.save!
      end
      expect( UpdateAction.unviewed_by_user_from_query( s.user_id, resource: t ) ).to eq true
    end

    it "should generate an update for descendent taxa" do
      t1 = Taxon.make!( rank: Taxon::GENUS )
      t2 = Taxon.make!( parent: t1, rank: Taxon::SPECIES )
      s = Subscription.make!( resource: t1 )
      o = Observation.make( taxon: t2 )
      expect( UpdateAction.unviewed_by_user_from_query( s.user_id, resource: t1 ) ).to eq false
      without_delay do
        o.save!
      end
      expect( UpdateAction.unviewed_by_user_from_query( s.user_id, resource: t1 ) ).to eq true
    end

    # This ended up being really annoying for people subscribed to high level
    # taxa like Anisoptera. Still feel like there's a better way to do this than
    # triggering it on create
    # it "should generate an update for an observation that changed to the subscribed taxon" do
    #   t = Taxon.make!
    #   s = Subscription.make!(:resource => t)
    #   Update.delete_all
    #   o = without_delay {Observation.make!}
    #   Update.count.should eq 0
    #   without_delay do
    #     o.update( taxon: t, editing_user_id: o.user_id )
    #   end
    #   u = Update.last
    #   u.should_not be_blank
    #   u.notifier.should eq(o)
    #   u.subscriber.should eq(s.user)
    # end
  end

  describe "place updates" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    describe "for places that cross the date line" do
      let( :place ) do
        # crude shape that includes the north and south island of New Zealand
        # (west of 180) and the Chathams (east of 180)
        wkt = <<-WKT
          MULTIPOLYGON
            (
              (
                (
                  -177.374267578125 -43.4449429552612,-177.396240234375
                  -44.5278427984555,-175.1220703125
                  -44.629573191951,-174.9462890625
                  -43.4289879234416,-177.374267578125 -43.4449429552612
                )
              ),(
                (
                  180 -33.9433599465788,179.736328125
                  -48.1074311884804,164.970703125 -47.8131545175277,165.234375
                  -33.3580616127788,180 -33.9433599465788
                )
              )
            )
        WKT
        make_place_with_geom( ewkt: wkt.gsub( /\s+/, " " ) )
      end
      before do
        expect( place.straddles_date_line? ).to be true
        @subscription = Subscription.make!( resource: place )
        @christchurch_lat = -43.603555
        @christchurch_lon = 172.652311
      end
      it "should generate" do
        o = without_delay do
          Observation.make!( latitude: @christchurch_lat, longitude: @christchurch_lon )
        end
        expect( o.public_places.map( &:id ) ).to include place.id
        expect( UpdateAction.unviewed_by_user_from_query( @subscription.user_id, notifier: o ) ).to eq true
      end
      it "should not generate for observations outside of that place" do
        o = without_delay do
          Observation.make!( latitude: -1 * @christchurch_lat, longitude: @christchurch_lon )
        end
        expect( UpdateAction.unviewed_by_user_from_query( @subscription.user_id, notifier: o ) ).to eq false
      end
    end
  end

  describe "update_for_taxon_change" do
    before( :each ) do
      @taxon_swap = TaxonSwap.make
      @input_taxon = Taxon.make!( rank: Taxon::FAMILY )
      @output_taxon = Taxon.make!( rank: Taxon::FAMILY )
      @taxon_swap.add_input_taxon( @input_taxon )
      @taxon_swap.add_output_taxon( @output_taxon )
      @taxon_swap.save!
      @obs_of_input = Observation.make!( taxon: @input_taxon )
    end

    it "should add new identifications" do
      expect( @obs_of_input.identifications.size ).to eq( 1 )
      expect( @obs_of_input.identifications.first.taxon ).to eq( @input_taxon )
      Observation.update_for_taxon_change( @taxon_swap )
      @obs_of_input.reload
      expect( @obs_of_input.identifications.size ).to eq( 2 )
      expect( @obs_of_input.identifications.detect {| i | i.taxon_id == @output_taxon.id } ).not_to be_blank
    end

    it "should not update old identifications" do
      old_ident = @obs_of_input.identifications.first
      expect( old_ident.taxon ).to eq( @input_taxon )
      Observation.update_for_taxon_change( @taxon_swap, @output_taxon )
      old_ident.reload
      expect( old_ident.taxon ).to eq( @input_taxon )
    end
  end

  describe "captive" do
    it "should vote yes on the wild quality metric if 1" do
      o = Observation.make!( captive_flag: "1" )
      expect( o.quality_metrics ).not_to be_blank
      expect( o.quality_metrics.first.user ).to eq( o.user )
      expect( o.quality_metrics.first ).not_to be_agree
    end

    it "should vote no on the wild quality metric if 0 and metric exists" do
      o = Observation.make!( captive_flag: "1" )
      expect( o.quality_metrics ).not_to be_blank
      o.update( captive_flag: "0" )
      expect( o.quality_metrics.first ).to be_agree
    end

    it "should not alter quality metrics if nil" do
      o = Observation.make!( captive_flag: nil )
      expect( o.quality_metrics ).to be_blank
    end

    it "should not alter quality metrics if 0 and not metrics exist" do
      o = Observation.make!( captive_flag: "0" )
      expect( o.quality_metrics ).to be_blank
    end
  end

  describe "merge" do
    let( :user ) { User.make! }
    let( :reject ) { Observation.make!( user: user ) }
    let( :keeper ) { Observation.make!( user: user ) }

    it "should destroy the reject" do
      keeper.merge( reject )
      expect( Observation.find_by_id( reject.id ) ).to be_blank
    end

    it "should preserve photos" do
      op = make_observation_photo( observation: reject )
      keeper.merge( reject )
      op.reload
      expect( op.observation ).to eq( keeper )
    end

    it "should preserve comments" do
      c = Comment.make!( parent: reject )
      keeper.merge( reject )
      c.reload
      expect( c.parent ).to eq( keeper )
    end

    it "should preserve identifications" do
      i = Identification.make!( observation: reject )
      keeper.merge( reject )
      i.reload
      expect( i.observation ).to eq( keeper )
    end

    it "should mark duplicate identifications as not current" do
      t = Taxon.make!
      without_delay do
        reject.update( taxon: t, editing_user_id: reject.user_id )
        keeper.update( taxon: t, editing_user_id: keeper.user_id )
      end
      keeper.merge( reject )
      idents = keeper.identifications.where( user_id: keeper.user_id ).order( "id asc" )
      expect( idents.size ).to eq( 2 )
      expect( idents.first ).not_to be_current
      expect( idents.last ).to be_current
    end
  end

  describe "component_cache_key" do
    it "should be the same regardless of option order" do
      k1 = Observation.component_cache_key( 111, for_owner: true, locale: :en )
      k2 = Observation.component_cache_key( 111, locale: :en, for_owner: true )
      expect( k1 ).to eq( k2 )
    end
  end

  describe "dynamic taxon getters" do
    it "should not interfere with taxon_id"
    it "should return genus"
  end

  describe "dynamic place getters" do
    it "should return place state" do
      p = make_place_with_geom( place_type: Place::PLACE_TYPE_CODES["State"] )
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude )
      expect( o.intersecting_places ).not_to be_blank
      expect( o.place_state ).to eq p
      expect( o.place_state_name ).to eq p.name
    end

    it "should return place county" do
      p = make_place_with_geom( place_type: Place::PLACE_TYPE_CODES["County"] )
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude )
      expect( o.intersecting_places ).not_to be_blank
      expect( o.place_county ).to eq p
      expect( o.place_county_name ).to eq p.name
    end

    it "should return place county by admin level if type is different" do
      p = make_place_with_geom(
        place_type: Place::PLACE_TYPE_CODES["Parish"],
        admin_level: Place::COUNTY_LEVEL
      )
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude )
      expect( o.intersecting_places ).not_to be_blank
      expect( o.place_county ).to eq p
      expect( o.place_county_name ).to eq p.name
    end

    it "should return admin level place" do
      p = make_place_with_geom(
        place_type: Place::PLACE_TYPE_CODES["County"],
        admin_level: Place::COUNTY_LEVEL
      )
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude )
      expect( o.intersecting_places ).not_to be_blank
      expect( o.place_admin2 ).to eq p
      expect( o.place_admin2_name ).to eq p.name
    end
  end

  describe "community taxon" do
    it "should be set if user has opted out" do
      u = User.make!( prefers_community_taxa: false )
      o = Observation.make!( user: u )
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.community_taxon ).not_to be_blank
    end

    it "should be set if user has opted out and community agrees with user" do
      u = User.make!( prefers_community_taxa: false )
      o = Observation.make!( taxon: Taxon.make!, user: u )
      Identification.make!( observation: o, taxon: o.taxon )
      o.reload
      expect( o.community_taxon ).to eq o.taxon
    end

    it "should be set if observation is opted out" do
      o = Observation.make!( prefers_community_taxon: false )
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.community_taxon ).not_to be_blank
    end

    it "should be set if observation is opted in but user is opted out" do
      u = User.make!( prefers_community_taxa: false )
      o = Observation.make!( prefers_community_taxon: true, user: u )
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.community_taxon ).to eq i1.taxon
    end

    it "should be set when preference set to true" do
      o = Observation.make!( prefers_community_taxon: false )
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.taxon ).to be_blank
      o.update( prefers_community_taxon: true )
      o.reload
      expect( o.community_taxon ).to eq( i1.taxon )
    end

    it "should not be unset when preference set to false" do
      o = Observation.make!
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.community_taxon ).to eq( i1.taxon )
      o.update( prefers_community_taxon: false )
      o.reload
      expect( o.community_taxon ).not_to be_blank
    end

    it "should set the taxon" do
      o = Observation.make!
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.taxon ).to eq o.community_taxon
    end

    it "should set the species_guess" do
      o = Observation.make!
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.species_guess ).to eq o.community_taxon.name
    end

    it "should set the iconic taxon" do
      o = Observation.make!
      expect( o.iconic_taxon ).to be_blank
      iconic_taxon = Taxon.make!( is_iconic: true, rank: "family" )
      i1 = Identification.make!( observation: o, taxon: Taxon.make!( parent: iconic_taxon, rank: "genus" ) )
      Identification.make!( observation: o, taxon: i1.taxon )
      expect( i1.taxon.iconic_taxon ).to eq iconic_taxon
      o.reload
      expect( o.taxon ).to eq i1.taxon
      expect( o.iconic_taxon ).to eq iconic_taxon
    end

    it "should not set the taxon if the user has opted out" do
      u = User.make!( prefers_community_taxa: false )
      o = Observation.make!( user: u )
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.taxon ).to be_blank
    end

    it "should not set the taxon if the observation is opted out" do
      o = Observation.make!( prefers_community_taxon: false )
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.taxon ).to be_blank
    end

    it "should not set the taxon if there are no identifications and the user chose a taxon" do
      t = Taxon.make!
      o = Observation.make( taxon: t )
      expect( o.identifications.size ).to eq 0
      expect( o.taxon ).to eq t
      o.save!
      o.reload
      expect( o.taxon ).to eq t
    end

    it "should change the taxon to the owner's identication when observation opted out" do
      owner_taxon = Taxon.make!
      o = Observation.make!( taxon: owner_taxon )
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.community_taxon ).to eq( i1.taxon )
      expect( o.taxon ).to eq o.community_taxon
      o.update( prefers_community_taxon: false )
      o.reload
      expect( o.taxon ).to eq owner_taxon
    end

    it "should set the species_guess when opted out" do
      owner_taxon = Taxon.make!
      o = Observation.make!( taxon: owner_taxon )
      i1 = Identification.make!( observation: o )
      Identification.make!( observation: o, taxon: i1.taxon )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.community_taxon ).to eq( i1.taxon )
      expect( o.taxon ).to eq o.community_taxon
      o.update( prefers_community_taxon: false )
      o.reload
      expect( o.species_guess ).to eq owner_taxon.name
    end

    it "should set the taxon if observation is opted in but user is opted out" do
      u = User.make!( prefers_community_taxa: false )
      o = Observation.make!( prefers_community_taxon: true, user: u )
      i1 = Identification.make!( observation: o, taxon: Taxon.make!( :species ) )
      Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.taxon ).to eq o.community_taxon
    end

    it "should not be set if there is only one current identification" do
      o = Observation.make!
      Identification.make!( observation: o, user: o.user )
      Identification.make!( observation: o, user: o.user )
      o.reload
      expect( o.community_taxon ).to be_blank
    end

    it "should not be set for 2 roots" do
      o = Observation.make!
      Identification.make!( observation: o )
      Identification.make!( observation: o )
      o.reload
      expect( o.community_taxon ).to be_blank
    end

    it "should be set to Life for two phyla" do
      load_test_taxa
      o = Observation.make!
      Identification.make!( observation: o, taxon: @Animalia )
      Identification.make!( observation: o, taxon: @Plantae )
      o.reload
      expect( o.community_taxon ).to eq @Life
    end

    it "change should be triggered by changing the taxon" do
      load_test_taxa
      o = Observation.make!
      Identification.make!( observation: o, taxon: @Animalia )
      expect( o.community_taxon ).to be_blank
      o = Observation.find( o.id )
      o.update( taxon: @Plantae, editing_user_id: o.user_id )
      expect( o.community_taxon ).not_to be_blank
      expect( o.identifications.count ).to eq 2
    end

    it "change should be triggered by activating a taxon" do
      load_test_taxa
      o = Observation.make!
      Identification.make!( observation: o, taxon: @Pseudacris_regilla )
      Identification.make!( observation: o, taxon: @Pseudacris_regilla )
      expect( o.community_taxon ).not_to be_blank
      t = Taxon.make!( parent: @Hylidae, rank: "genus", is_active: false )
      expect( t.is_active ).to be( false )
      @Pseudacris_regilla.update( is_active: false )
      expect( @Pseudacris_regilla.is_active ).to be( false )
      @Pseudacris_regilla.parent = t
      @Pseudacris_regilla.save
      expect( @Pseudacris_regilla.parent ).to eq( t )
      Delayed::Worker.new.work_off
      o = Observation.find( o.id )
      expect( o.community_taxon ).to be_blank
      @Pseudacris_regilla.parent = @Pseudacris
      @Pseudacris_regilla.save
      Delayed::Worker.new.work_off
      @Pseudacris_regilla.update( is_active: true )
      Delayed::Worker.new.work_off
      o = Observation.find( o.id )
      expect( o.community_taxon ).not_to be_blank
    end

    it "should obscure the observation if set to a threatened taxon if the owner has an ID " \
      "but the community confirms a descendant" do
      p = Taxon.make!( rank: "genus" )
      t = Taxon.make!( parent: p, rank: "species" )
      ConservationStatus.make!( taxon: t )
      o = Observation.make!( latitude: 1, longitude: 1, taxon: p )
      expect( o ).not_to be_coordinates_obscured
      expect( o.taxon ).not_to be_blank
      Identification.make!( taxon: t, observation: o )
      Identification.make!( taxon: t, observation: o )
      o.reload
      expect( o.community_taxon ).to eq t
      expect( o ).to be_coordinates_obscured
    end

    it "should obscure the observation if set to a threatened taxon but the owner has no ID" do
      cs = ConservationStatus.make!
      t = cs.taxon
      o = Observation.make!( latitude: 1, longitude: 1 )
      expect( o.taxon ).to be_blank
      Identification.make!( taxon: t, observation: o )
      Identification.make!( taxon: t, observation: o )
      o.reload
      expect( o.taxon ).to eq t
      expect( o ).to be_coordinates_obscured
    end

    it "should not consider identifications of inactive taxa" do
      g1 = Taxon.make!( rank: Taxon::GENUS, name: "Genusone" )
      s1 = Taxon.make!( rank: Taxon::SPECIES, parent: g1, name: "Genus speciesone" )
      s2 = Taxon.make!( rank: Taxon::SPECIES, parent: g1, name: "Genus speciestwo", is_active: false )
      o = Observation.make!
      Identification.make!( observation: o, taxon: s1 )
      Identification.make!( observation: o, taxon: s1 )
      Identification.make!( observation: o, taxon: s2 )
      o.reload
      expect( o.community_taxon ).to eq s1
    end

    describe "test cases: " do
      before { setup_test_case_taxonomy }

      it "s1 s1 s2" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s2 )
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "s1 s1 g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1 )
        @o.reload
        expect( @o.community_taxon ).to eq @s1
      end

      it "s1 s1 g1.disagreement_nil" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        i = Identification.make!( observation: @o, taxon: @g1 )
        i.update_attribute( :disagreement, nil )
        i.reload
        expect( i.disagreement ).to eq nil
        @o.reload
        @o.set_community_taxon( force: true )
        expect( @o.community_taxon ).to eq @g1
      end

      it "s1 s1 g1.disagreement" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: true )
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "s1 s1 g1.disagreement_false" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        @o.reload
        expect( @o.community_taxon ).to eq @s1
      end

      it "s1 s1 s1 g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1 )
        @o.reload
        expect( @o.community_taxon ).to eq @s1
      end

      it "s1 s1 s2 s2" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @s2 )
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "f f f f ss1 s2 s2 s2 s2" do
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @s2 )
        @o.reload
        expect( @o.community_taxon ).to eq @s2
      end

      it "f f f f ss1 ss1 s2 s2 s2 s2 g1" do
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @g1 )
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "f g1 s1 (should not taxa with only one ID to be the community taxon)" do
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @g1 )
        Identification.make!( observation: @o, taxon: @s1 )
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "f f g1 s1" do
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @g1 )
        Identification.make!( observation: @o, taxon: @s1 )
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "s1 s1 f f" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        @o.reload
        expect( @o.community_taxon ).to eq @s1
      end

      it "s1 s1 f.disagreement f" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @f, disagreement: true )
        Identification.make!( observation: @o, taxon: @f )
        @o.reload
        expect( @o.community_taxon ).to eq @f
      end

      it "s1 s2 f.disagreement g2 s1.withdraw s2.withdraw" do
        i1 = Identification.make!( observation: @o, taxon: @s1 )
        i2 = Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @f, disagreement: true )
        Identification.make!( observation: @o, taxon: @g2 )
        Identification.make!( observation: @o, taxon: @g2 )

        i1.update_attribute( :current, false )
        i1.reload
        expect( i1.current ).to eq false
        i2.update_attribute( :current, false )
        i2.reload
        expect( i2.current ).to eq false
        @o.reload
        @o.set_community_taxon( force: true )

        expect( @o.community_taxon ).to eq @g2
      end

      it "s1 s2 f.disagreement g2 s1.withdraw" do
        i1 = Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @f, disagreement: true )
        Identification.make!( observation: @o, taxon: @g2 )
        Identification.make!( observation: @o, taxon: @g2 )

        i1.update_attribute( :current, false )
        i1.reload
        expect( i1.current ).to eq false
        @o.reload
        @o.set_community_taxon( force: true )

        expect( @o.community_taxon ).to eq @f
      end
    end
  end

  describe "probable_taxon" do
    describe "test cases: " do
      before { setup_test_case_taxonomy }
      it "s1 should be s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        @o.reload
        expect( @o.probable_taxon ).to eq @s1
      end
      it "s1 g1.disagreement_true should be g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: true )
        @o.reload
        expect( @o.probable_taxon ).to eq @g1
      end
      it "s1 g1.disagreement_nil should be g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        i = Identification.make!( observation: @o, taxon: @g1 )
        i.update_attribute( :disagreement, nil )
        o = Observation.find( @o.id )
        expect( o.probable_taxon ).to eq @g1
      end
      it "s1 g1.disagreement_false should be s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        @o.reload
        expect( @o.probable_taxon ).to eq @s1
      end
      it "ss1 s1.disagreement_false should be ss1" do
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s1, disagreement: false )
        @o.reload
        expect( @o.probable_taxon ).to eq @ss1
      end
      it "s1 g1.disagreement_false g1.disagreement_false should be s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        @o.reload
        expect( @o.probable_taxon ).to eq @s1
      end
      it "s1 g1.disagreement_false should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        @o.reload
        expect( @o.taxon ).to eq @s1
      end
      it "s1 s2 should be g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s2 )
        @o.reload
        expect( @o.probable_taxon ).to eq @g1
      end
      it "s1 s2 should set taxon to g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s2 )
        @o.reload
        expect( @o.taxon ).to eq @g1
      end
      it "g2 s1 should set taxon to f" do
        Identification.make!( observation: @o, taxon: @g2 )
        Identification.make!( observation: @o, taxon: @s1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @f
      end
      it "s1 ss1 should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @ss1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "s1 s1 ss1 should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @ss1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "ss1 s1.disagreement_false should set the taxon to ss1" do
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s1, disagreement: false )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @ss1
      end
      it "ss1 s1.disagreement_true should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s1, disagreement: true )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "s1 ss1 should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @ss1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "g1 ss1 should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @g1 )
        Identification.make!( observation: @o, taxon: @ss1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "ss1 s2ss1 should set the taxon to g1" do
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s2ss1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @g1
      end
      it "s1.disagreement_false s2.disagreement_false s2.disagreement_false should be g1" do
        @taxon_swap1 = TaxonSwap.make
        @taxon_swap1.add_input_taxon( @s3 )
        @taxon_swap1.add_output_taxon( @s1 )
        @taxon_swap1.save!
        @taxon_swap2 = TaxonSwap.make
        @taxon_swap2.add_input_taxon( @s4 )
        @taxon_swap2.add_output_taxon( @s2 )
        @taxon_swap2.save!

        Identification.make!( observation: @o, taxon: @s3 )
        Identification.make!( observation: @o, taxon: @s4 )
        @o.reload
        expect( @o.identifications.size ).to eq( 2 )
        expect( @o.identifications.detect {| i | i.taxon_id == @s3.id } ).not_to be_blank

        @user = make_user_with_role( :admin, created_at: Time.now )
        @taxon_swap1.committer = @user
        @taxon_swap2.committer = @user
        @taxon_swap1.commit
        Delayed::Worker.new.work_off
        @taxon_swap2.commit
        Delayed::Worker.new.work_off
        @s4.reload
        expect( @s4.is_active ).to be false
        @o.reload
        expect( @o.identifications.size ).to eq( 4 )
        expect( @o.identifications.detect {| i | i.taxon_id == @s3.id } ).not_to be_blank

        Identification.make!( observation: @o, taxon: @s2, disagreement: false )
        @o.reload
        expect( @o.probable_taxon ).to eq @g1
      end

      it "g2 f.disagreement_true s1" do
        i1 = Identification.make!( observation: @o, taxon: @g2 )
        Identification.make!( observation: @o, taxon: @f, disagreement: true )
        Identification.make!( observation: @o, taxon: @s1, user: i1.user )
        expect( @o.probable_taxon ).to eq @s1
      end

      it "ignores hidden identifications" do
        i = Identification.make!( observation: @o, taxon: @s1 )
        @o = Observation.find( @o.id )
        expect( @o.taxon ).to eq @s1
        ModeratorAction.make!( resource: i, action: ModeratorAction::HIDE )
        @o = Observation.find( @o.id )
        expect( @o.taxon ).to be_nil
      end

      it "resets after hiding identifications" do
        Identification.make!( observation: @o, taxon: @s1 )
        i2 = Identification.make!( observation: @o, taxon: @s2 )
        @o = Observation.find( @o.id )
        expect( @o.taxon ).to eq @g1
        ModeratorAction.make!( resource: i2, action: ModeratorAction::HIDE )
        @o = Observation.find( @o.id )
        expect( @o.taxon ).to eq @s1
      end

      it "s1 s2 f.disagreement g2 s1.withdraw s2.withdraw" do
        i1 = Identification.make!( observation: @o, taxon: @s1 )
        i2 = Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @f, disagreement: true )
        Identification.make!( observation: @o, taxon: @g2 )

        i1.update_attribute( :current, false )
        i1.reload
        expect( i1.current ).to eq false
        i2.update_attribute( :current, false )
        i2.reload
        expect( i2.current ).to eq false
        @o.reload

        expect( @o.taxon ).to eq @g2
      end

      it "s1 s2 f.disagreement g2 s1.withdraw" do
        i1 = Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s2 )
        Identification.make!( observation: @o, taxon: @f, disagreement: true )
        Identification.make!( observation: @o, taxon: @g2 )

        i1.update_attribute( :current, false )
        i1.reload
        expect( i1.current ).to eq false
        @o.reload

        expect( @o.taxon ).to eq @f
      end
    end
  end

  describe "fields_addable_by?" do
    let( :observer ) { build_stubbed :user }
    let( :observation ) { build_stubbed :observation, user: observer }
    let( :field_adder ) { build_stubbed :user }

    subject { observation.fields_addable_by? field_adder }

    context "for anyone else" do
      it { is_expected.to be true }

      context "no editing preferred" do
        let( :observer_preference ) { User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER }
        let( :observer ) { build_stubbed :user, preferred_observation_fields_by: observer_preference }

        it { is_expected.to be false }
      end
    end

    context "for nil user" do
      let( :field_adder ) { nil }

      it { is_expected.to be false }
    end

    context "for curator" do
      let( :field_adder ) { build_stubbed :curator }

      it { is_expected.to be true }

      context "and curators preferred" do
        let( :observer_preference ) { User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS }
        let( :observer ) { build_stubbed :user, preferred_observation_fields_by: observer_preference }

        it { is_expected.to be true }
      end

      context "and no editing preferred" do
        let( :observer_preference ) { User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER }
        let( :observer ) { build_stubbed :user, preferred_observation_fields_by: observer_preference }

        it { is_expected.to be false }
      end
    end

    context "for observer" do
      let( :field_adder ) { observer }

      context "and no editing preferred" do
        let( :observer_preference ) { User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER }
        let( :observer ) { build_stubbed :user, preferred_observation_fields_by: observer_preference }

        it { is_expected.to be true }
      end
    end
  end

  describe "timezone_object" do
    it "returns nil when given nil" do
      o = Observation.make!
      o.update_column( :time_zone, nil )
      o.update_column( :zic_time_zone, nil )
      expect( o.time_zone ).to be nil
      expect( o.timezone_object ).to be nil
    end
  end

  describe "reviewed_by?" do
    it "knows who it was reviewed by" do
      o = Observation.make!
      expect( o.reviewed_by?( o.user ) ).to be false
      ObservationReview.make!( observation: o, user: o.user )
      expect( o.reviewed_by?( o.user ) ).to be true
    end

    it "doesn't count unreviews" do
      o = Observation.make!
      expect( o.reviewed_by?( o.user ) ).to be false
      ObservationReview.make!( observation: o, user: o.user, reviewed: false )
      expect( o.reviewed_by?( o.user ) ).to be false
    end
  end

  describe "mentions" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "knows what users have been mentioned" do
      u = User.make!
      o = Observation.make!( description: "hey @#{u.login}" )
      expect( o.mentioned_users ).to eq [u]
    end

    it "generates mention updates" do
      u = User.make!
      o = after_delayed_job_finishes( ignore_run_at: true ) { Observation.make!( description: "hey @#{u.login}" ) }
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq true
    end

    it "generates mention updates for observations with photos" do
      u = User.make!
      o = after_delayed_job_finishes( ignore_run_at: true ) do
        make_research_grade_observation( description: "hey @#{u.login}" )
      end
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq true
    end

    it "does not generation a mention update if the description was updated and the mentioned " \
      "user wasn't in the new content" do
      u = User.make!
      o = without_delay { Observation.make!( description: "hey @#{u.login}" ) }
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq true
      # mark the generated updates as viewed
      UpdateAction.user_viewed_updates( UpdateAction.where( notifier: o ), u.id )
      after_delayed_job_finishes do
        o.update( description: "#{o.description} and some extra" )
      end
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq false
    end
    it "removes mention updates if the description was updated to remove the mentioned user" do
      u = User.make!
      o = without_delay { Observation.make!( description: "hey @#{u.login}" ) }
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq true
      after_delayed_job_finishes( ignore_run_at: true ) { o.update( description: "bye" ) }
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq false
    end
    it "generates a mention update if the description was updated and the mentioned user was in the new content" do
      u = User.make!
      o = without_delay { Observation.make!( description: "hey" ) }
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq false
      after_delayed_job_finishes( ignore_run_at: true ) do
        o.update( description: "#{o.description} @#{u.login}" )
      end
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq true
    end
  end

  describe "dedupe_for_user" do
    before do
      @obs = Observation.make!(
        observed_on_string: "2015-01-01",
        latitude: 1,
        longitude: 1,
        taxon: Taxon.make!
      )
      @dupe = Observation.make!(
        observed_on_string: @obs.observed_on_string,
        latitude: @obs.latitude,
        longitude: @obs.longitude,
        taxon: @obs.taxon,
        user: @obs.user
      )
    end
    it "should remove duplicates" do
      Observation.dedupe_for_user( @obs.user )
      expect( Observation.find_by_id( @obs.id ) ).not_to be_blank
      expect( Observation.find_by_id( @dupe.id ) ).to be_blank
    end
    it "should remove duplicates with obscured coordinates" do
      @dupe.update( geoprivacy: Observation::OBSCURED )
      Observation.dedupe_for_user( @obs.user )
      expect( Observation.find_by_id( @obs.id ) ).not_to be_blank
      expect( Observation.find_by_id( @dupe.id ) ).to be_blank
    end
    it "should not assume null datetimes are the same" do
      @obs.update( observed_on_string: nil )
      @dupe.update( observed_on_string: nil )
      Observation.dedupe_for_user( @obs.user )
      expect( Observation.find_by_id( @obs.id ) ).not_to be_blank
      expect( Observation.find_by_id( @dupe.id ) ).not_to be_blank
    end
    it "should not assume blank datetimes are the same" do
      @obs.update( observed_on_string: "" )
      @dupe.update( observed_on_string: "" )
      Observation.dedupe_for_user( @obs.user )
      expect( Observation.find_by_id( @obs.id ) ).not_to be_blank
      expect( Observation.find_by_id( @dupe.id ) ).not_to be_blank
    end
    it "should not assume null coordinates are the same" do
      @obs.update( latitude: nil, longitude: nil )
      @dupe.update( latitude: nil, longitude: nil )
      Observation.dedupe_for_user( @obs.user )
      expect( Observation.find_by_id( @obs.id ) ).not_to be_blank
      expect( Observation.find_by_id( @dupe.id ) ).not_to be_blank
    end
    it "should not assume null taxa are the same" do
      @obs.update( taxon: nil, editing_user_id: @obs.user_id )
      @dupe.update( taxon: nil, editing_user_id: @dupe.user_id )
      Observation.dedupe_for_user( @obs.user )
      expect( Observation.find_by_id( @obs.id ) ).not_to be_blank
      expect( Observation.find_by_id( @dupe.id ) ).not_to be_blank
    end
  end
end

describe Observation, "probably_captive?" do
  elastic_models( Observation )

  describe "returns correct value" do
    let( :species ) { create :taxon, :as_species }
    let( :place ) { create :place, :with_geom, admin_level: Place::COUNTRY_LEVEL }
    include ElasticStub

    def stub_observations( count = 1, **kwargs )
      defaults = { captive: false, taxon: species, latitude: place.latitude, longitude: place.longitude }
      elastic_stub_observations( count ) do
        build_stubbed( :observation, defaults.merge( **kwargs ) ) do | obs |
          allow( obs ).to receive( :public_places ).and_return [place]
          obs.update_quality_metrics
          obs.captive = obs.captive_cultivated
        end
      end
    end

    before do | e |
      allow( Observation ).to receive( :system_places_for_latlon ).and_return [place] unless e.metadata[:skip_before]
    end
    it "should be false with under 10 captive obs" do
      stub_observations 9, captive_flag: true

      expect( stub_observations ).not_to be_probably_captive
    end
    it "should be true with more than 10 captive obs" do
      stub_observations 11, captive_flag: true

      expect( stub_observations ).to be_probably_captive
    end
    it "should require more than 80% captive" do
      stub_observations 11
      stub_observations 11, captive_flag: true

      expect( stub_observations ).not_to be_probably_captive
    end
    it "should be false with no coordinates", skip_before: true do
      stub_observations 11, captive_flag: true

      expect( stub_observations( 1, latitude: nil, longitude: nil ) ).not_to be_probably_captive
    end
    it "should be false with no taxon" do
      stub_observations 11, captive_flag: true

      expect( stub_observations( 1, taxon: nil ) ).not_to be_probably_captive
    end
    it "should use the community taxon if present" do
      stub_observations 11, captive_flag: true
      o = create :observation, latitude: place.latitude, longitude: place.longitude, prefers_community_taxon: false
      create_list :identification, 4, observation: o, taxon: species
      o.reload

      expect( o.taxon ).not_to eq species
      expect( o.community_taxon ).to eq species
      expect( o ).to be_probably_captive
    end
  end

  describe Observation, "and update_quality_metrics" do
    let( :taxon ) { Taxon.make!( rank: Taxon::SPECIES ) }
    let( :place ) { make_place_with_geom( admin_level: Place::COUNTRY_LEVEL ) }
    def make_captive_obs
      Observation.make!( taxon: taxon, captive_flag: true, latitude: place.latitude, longitude: place.longitude )
    end

    def make_non_captive_obs
      Observation.make!( taxon: taxon, latitude: place.latitude, longitude: place.longitude )
    end
    it "should add a userless quality metric if probably_captive?" do
      11.times { make_captive_obs }
      o = make_non_captive_obs
      o.reload
      expect( o ).to be_captive
      expect(
        o.quality_metrics.detect {| m | m.user_id.blank? && m.metric == QualityMetric::WILD }
      ).not_to be_blank
    end
    it "should remove the quality metric if not probably_captive? anymore" do
      11.times { make_captive_obs }
      o = make_non_captive_obs
      o.reload
      expect( o ).to be_captive
      11.times do
        obs = make_non_captive_obs
        QualityMetric.vote( nil, obs, QualityMetric::WILD, true )
      end
      o.update( description: "foo" )
      o.reload
      expect( o ).not_to be_captive
      expect(
        o.quality_metrics.detect {| m | m.user_id.blank? && m.metric == QualityMetric::WILD }
      ).to be_blank
    end
  end
end

describe "ident getters" do
  it "should return taxon_id for a particular user by login" do
    u = User.make!( login: "balthazar_salazar" )
    i = Identification.make!( user: u )
    o = i.observation
    o.reload
    expect( o.send( "ident_by_balthazar_salazar:taxon_id" ) ).to eq i.taxon_id
  end

  it "should return taxon name for a particular user by login" do
    u = User.make!( login: "balthazar_salazar" )
    i = Identification.make!( user: u )
    o = i.observation
    o.reload
    expect( o.send( "ident_by_balthazar_salazar:taxon_name" ) ).to eq i.taxon.name
  end

  it "should return taxon_id for a particular user by id" do
    u = User.make!
    i = Identification.make!( user: u )
    o = i.observation
    o.reload
    expect( o.send( "ident_by_#{u.id}:taxon_id" ) ).to eq i.taxon_id
  end
end

describe "observation field value getter" do
  it "should get the value of an observation field" do
    ofv = ObservationFieldValue.make!
    expect(
      ofv.observation.send( "field:#{ofv.observation_field.name}" )
    ).to eq ofv.value
  end

  it "should work for observation fields with colons" do
    of = ObservationField.make!( name: "dwc:locality" )
    ofv = ObservationFieldValue.make!( observation_field: of )
    expect(
      ofv.observation.send( "field:#{ofv.observation_field.name}" )
    ).to eq ofv.value
  end

  it "should work for observation fields with other non-word characters" do
    of = ObservationField.make!( name: "\% cover" )
    ofv = ObservationFieldValue.make!( observation_field: of )
    expect(
      ofv.observation.send( "field:#{ofv.observation_field.name}" )
    ).to eq ofv.value
  end
end

describe Observation, "and update_quality_metrics" do
  it "should not throw an error of owner ID taxon has no rank level" do
    o = make_research_grade_observation
    o.update( prefers_community_taxon: false )
    o.owners_identification.taxon.update( rank: "nonsense" )
    expect do
      o.get_quality_grade
    end.to_not raise_error
  end
end

describe Observation, "taxon_geoprivacy" do
  let!( :p ) { make_place_with_geom }
  let!( :cs ) { ConservationStatus.make!( place: p ) }
  let( :o ) do
    o = Observation.make!
    Observation.where( id: o.id ).update_all(
      latitude: p.latitude + 10,
      longitude: p.longitude + 10,
      private_latitude: p.latitude,
      private_longitude: p.longitude
    )
    o.reload
  end
  it "should be set using private coordinates" do
    expect( p ).to be_contains_lat_lng( o.private_latitude, o.private_longitude )
    expect( p ).not_to be_contains_lat_lng( o.latitude, o.longitude )
    Identification.make!( observation: o, taxon: cs.taxon )
    o.reload
    expect( o.taxon_geoprivacy ).to eq cs.geoprivacy
  end

  it "should restore taxon obscured coordinates when going from pivate to open" do
    Identification.make!( observation: o, taxon: cs.taxon )
    o.reload
    expect( o ).not_to be_coordinates_private
    expect( o ).to be_coordinates_obscured
    o.update( geoprivacy: Observation::PRIVATE )
    expect( o ).to be_coordinates_private
    o.reload
    o.update( geoprivacy: Observation::OPEN, latitude: o.private_latitude, longitude: o.private_longitude )
    o.reload
    expect( o ).not_to be_coordinates_private
    expect( o ).to be_coordinates_obscured
  end

  it "does not consider hidden identifications" do
    o = Observation.make!(
      latitude: p.latitude,
      longitude: p.longitude
    )
    expect( o.taxon_geoprivacy ).to be_nil
    expect( o ).not_to be_coordinates_obscured
    i = Identification.make!( observation: o, taxon: cs.taxon )
    expect( o.taxon_geoprivacy ).to eq cs.geoprivacy
    expect( o ).to be_coordinates_obscured
    ModeratorAction.make!( resource: i, action: ModeratorAction::HIDE )
    o.reload
    expect( o.taxon_geoprivacy ).to be_nil
    expect( o ).not_to be_coordinates_obscured
  end
end

describe Observation, "set_observations_taxa_for_user" do
  elastic_models( Observation )
  let( :user ) { User.make! }
  let( :family1 ) { Taxon.make!( rank: Taxon::FAMILY, name: "Familyone" ) }
  let( :genus1 ) { Taxon.make!( rank: Taxon::GENUS, name: "Genusone", parent: family1 ) }
  let( :species1 ) { Taxon.make!( rank: Taxon::SPECIES, name: "Genusone speciesone", parent: genus1 ) }
  let( :o ) do
    o = Observation.make!( user: user )
    Identification.make!( observation: o, user: user, taxon: genus1 )
    Identification.make!( observation: o, taxon: species1 )
    Identification.make!( observation: o, taxon: species1 )
    o
  end
  it "should change the community taxon if the observer's opted out of the community taxon" do
    expect( o.taxon ).to eq species1
    user.update( prefers_community_taxa: false )
    o.reload
    expect( o.taxon ).to eq species1
    Observation.set_observations_taxa_for_user( o.user_id )
    o.reload
    expect( o.taxon ).to eq genus1
  end
  it "should change the community taxon if the observer's opted in to the community taxon" do
    user.update( prefers_community_taxa: false )
    expect( o.taxon ).to eq genus1
    user.update( prefers_community_taxa: true )
    o.reload
    expect( o.taxon ).to eq genus1
    Observation.set_observations_taxa_for_user( o.user_id )
    o.reload
    expect( o.taxon ).to eq species1
  end
end

describe Observation, "set_time_zone" do
  before( :all ) { load_time_zone_geometries }
  after( :all ) { unload_time_zone_geometries }
  let( :oakland ) do
    {
      lat: 37.7586346,
      lng: -122.3753932
    }
  end
  let( :tucson ) do
    {
      lat: 32.1558328,
      lng: -111.023891
    }
  end
  let( :denver ) do
    {
      lat: 39.7642548,
      lng: -104.9951965
    }
  end
  let( :pacific_ocean ) do
    {
      lat: 22.204,
      lng: -123.836
    }
  end

  it "should default to the user time zone without coordinates" do
    o = Observation.make!
    expect( o.time_zone ).to eq o.user.time_zone
  end

  it "should set time zone based on location even if user time zone doesn't match" do
    o = Observation.make!( latitude: tucson[:lat], longitude: tucson[:lng] )
    expect( o.user.time_zone ).to eq "Pacific Time (US & Canada)"
    expect( o.time_zone ).to eq "Arizona"
    expect( o.zic_time_zone ).to eq "America/Phoenix"
  end

  it "should set time zone based on location even if observed_on_string doesn't match" do
    o = Observation.make!(
      observed_on_string: "2019-01-02 3:07:17 PM EST",
      latitude: oakland[:lat],
      longitude: oakland[:lng]
    )
    expect( o.time_zone ).to eq "Pacific Time (US & Canada)"
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
  end

  it "should change the time zone when the coordinates change" do
    o = Observation.make!( latitude: oakland[:lat], longitude: oakland[:lng] )
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
    o.update( latitude: denver[:lat], longitude: denver[:lng] )
    expect( o.zic_time_zone ).to eq "America/Denver"
  end

  it "should change the time zone when the coordinates change when geoprivacy is obscured" do
    o = Observation.make!( latitude: oakland[:lat], longitude: oakland[:lng], geoprivacy: Observation::OBSCURED )
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
    o.update( latitude: denver[:lat], longitude: denver[:lng] )
    expect( o.zic_time_zone ).to eq "America/Denver"
  end

  it "should work in the middle of the ocean" do
    o = Observation.make!(
      latitude: pacific_ocean[:lat],
      longitude: pacific_ocean[:lng]
    )
    expect( o.zic_time_zone ).to eq "Etc/GMT+8"
  end

  it "should use the zic_time_zone as the time_zone in the middle of the ocean" do
    o = Observation.make!(
      latitude: pacific_ocean[:lat],
      longitude: pacific_ocean[:lng]
    )
    expect( o.time_zone ).to eq o.zic_time_zone
  end

  it "should work when coordinates change to the middle of the ocean" do
    o = Observation.make!( latitude: oakland[:lat], longitude: oakland[:lng] )
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
    o.update( latitude: pacific_ocean[:lat], longitude: pacific_ocean[:lng] )
    expect( o.zic_time_zone ).to eq "Etc/GMT+8"
  end

  it "should set the zic_time_zone in the middle of the ocean" do
    o = Observation.make!(
      latitude: pacific_ocean[:lat],
      longitude: pacific_ocean[:lng]
    )
    expect( o.zic_time_zone ).to eq "Etc/GMT+8"
  end

  it "should set the zic_time_zone when coordinates change to the middle of the ocean" do
    o = Observation.make!( latitude: oakland[:lat], longitude: oakland[:lng] )
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
    o.update( latitude: pacific_ocean[:lat], longitude: pacific_ocean[:lng] )
    expect( o.zic_time_zone ).to eq "Etc/GMT+8"
  end
end

describe Observation, "sound_url" do
  let( :observation ) { Observation.make! }
  it "should return nil if there are no sounds" do
    expect( observation.sound_url ).to be_nil
  end

  it "should return the URL of the first sound" do
    sound = LocalSound.make!( user: observation.user )
    os = ObservationSound.make!( observation: observation, sound: sound )
    expect( observation.sound_url ).to eq os.sound.file.url
  end

  it "should not return hidden sounds" do
    sound = LocalSound.make!( user: observation.user )
    ObservationSound.make!( observation: observation, sound: sound )
    ModeratorAction.make!( resource: sound, action: "hide" )
    expect( sound.hidden? ).to be true
    expect( observation.sound_url ).to be_nil
  end
end

def setup_test_case_taxonomy
  # Tree:
  #          sf
  #          |
  #          f
  #       /     \
  #      g1     g2
  #     /  \
  #    s1  s2
  #   /  \   \
  # ss1  ss2 s2ss1

  # Superfamily intentionally left unavailable. Since it has a blank ancestry,
  # it will not really behave as expected in most tests
  sf = Taxon.make!( rank: "superfamily", name: "Superfamily" )
  @f = Taxon.make!( rank: "family", parent: sf, name: "Family" )
  @g1 = Taxon.make!( rank: "genus", parent: @f, name: "Genusone" )
  @g2 = Taxon.make!( rank: "genus", parent: @f, name: "Genustwo" )
  @s1 = Taxon.make!( rank: "species", parent: @g1, name: "Genusone speciesone" )
  @s2 = Taxon.make!( rank: "species", parent: @g1, name: "Genusone speciestwo" )
  @s3 = Taxon.make!( rank: "species", parent: @g1, name: "Genusone speciesthree" )
  @s4 = Taxon.make!( rank: "species", parent: @g1, name: "Genusone speciesfour" )
  @ss1 = Taxon.make!( rank: "subspecies", parent: @s1, name: "Genusone speciesone subspeciesone" )
  @ss2 = Taxon.make!( rank: "subspecies", parent: @s1, name: "Genusone speciesone subspeciestwo" )
  @s2ss1 = Taxon.make!( rank: "subspecies", parent: @s2, name: "Genusone speciestwo subspeciesone" )
  @o = Observation.make!
end
