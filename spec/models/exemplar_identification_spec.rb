# frozen_string_literal: true

require "spec_helper"

describe ExemplarIdentification do
  elastic_models( ExemplarIdentification )

  it { is_expected.to belong_to( :identification ) }
  it { is_expected.to belong_to( :nominated_by_user ).class_name "User" }

  it { is_expected.to validate_presence_of( :identification ) }

  describe "identification_body_has_text" do
    it "requires an identification body" do
      expect do
        ExemplarIdentification.make!( identification: Identification.make!( body: nil ) )
      end.to raise_error( ActiveRecord::RecordInvalid, /Identification requires a body/ )

      expect do
        ExemplarIdentification.make!( identification: Identification.make!( body: "" ) )
      end.to raise_error( ActiveRecord::RecordInvalid, /Identification requires a body/ )

      expect do
        ExemplarIdentification.make!( identification: Identification.make!( body: " " ) )
      end.to raise_error( ActiveRecord::RecordInvalid, /Identification requires a body/ )

      identification = Identification.make!( body: "the body" )
      # identifications create exemplar_identifications after_save
      expect( identification.exemplar_identification ).not_to be_nil
      expect( identification.exemplar_identification ).to be_valid
      identification.exemplar_identification.destroy

      expect do
        exemplar = ExemplarIdentification.make!( identification: identification )
        expect( exemplar ).to be_valid
      end.not_to raise_error
    end
  end

  describe "nominated_by_user_has_permission" do
    before do
      allow( CONFIG ).to receive( :content_creation_restriction_days ).and_return( 1 )
    end
    it "requires content creation privileges" do
      identification = Identification.make!( body: "the body" )
      identification.exemplar_identification.destroy

      expect do
        ExemplarIdentification.make!( identification: identification, nominated_by_user: User.make! )
      end.to raise_error(
        ActiveRecord::RecordInvalid,
        /#{I18n.t( 'activerecord.errors.messages.requires_privilege_organizer' )}/
      )

      new_organizer = User.make!( created_at: Time.now )
      UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER, user: new_organizer )
      expect do
        ExemplarIdentification.make!( identification: identification, nominated_by_user: new_organizer )
      end.to raise_error(
        ActiveRecord::RecordInvalid,
        /#{I18n.t( 'activerecord.errors.messages.requires_privilege_organizer' )}/
      )

      old_organizer = User.make!( created_at: 2.days.ago )
      UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER, user: old_organizer )
      expect do
        ExemplarIdentification.make!( identification: identification, nominated_by_user: old_organizer )
      end.not_to raise_error
    end
  end

  describe "set_nominated_at" do
    before do
      allow( CONFIG ).to receive( :content_creation_restriction_days ).and_return( 1 )
    end

    it "sets nominated_at when nominated_by_user changes" do
      identification = Identification.make!( body: "the body" )
      expect( identification.exemplar_identification.nominated_at ).to be_nil

      old_organizer = User.make!( created_at: 2.days.ago )
      UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER, user: old_organizer )
      identification.exemplar_identification.update( nominated_by_user: old_organizer )
      expect( identification.exemplar_identification.nominated_at ).not_to be_nil
      expect( identification.exemplar_identification.nominated_at ).to be > 10.seconds.ago
    end
  end

  describe "set_active" do
    let( :genus ) { Taxon.make!( rank: Taxon::GENUS ) }
    let( :species ) { Taxon.make!( rank: Taxon::SPECIES, parent: genus ) }

    it "sets active to true when identifications are species and consistent with observation taxon" do
      observation = Observation.make!( taxon: species )
      identification = Identification.make!( observation: observation, taxon: species, body: "thebody" )
      expect( identification.exemplar_identification.active? ).to be true
    end

    it "sets active to true when identifications are species and observations have no taxon yet" do
      observation = Observation.make!( taxon: nil )
      identification = Identification.new(
        observation: observation,
        taxon: species, body: "thebody",
        user: User.make!
      )
      # the Identification model implements a custom callback for the test env
      # due to conflicts with the test environment's transactional DB cleaning.
      # That callback changes the normal order of operations (turning an
      # after_commit into an after_create), and changing the normal data flow
      # this test is evaluating. Skip that callback for now to test the real
      # world case of an observation having no taxon when `set_active` is called
      expect( identification ).to receive( :update_observation_if_test_env ).and_return( nil )
      identification.save
      expect( identification.exemplar_identification.active? ).to be true
    end

    it "sets active to false when identifications are withdrawn" do
      observation = Observation.make!( taxon: species )
      identification = Identification.make!( observation: observation, taxon: species, body: "thebody" )
      expect( identification.exemplar_identification.active? ).to be true

      identification.update( current: false )
      expect( identification.exemplar_identification.active? ).to be false
    end

    it "sets active to false when identifications are not consistent with observation taxon" do
      observation = Observation.make!( taxon: species )
      identification = Identification.make!( observation: observation, taxon: species, body: "thebody" )
      expect( identification.exemplar_identification.active? ).to be true

      identification.update( taxon: Taxon.make!( rank: Taxon::SPECIES ) )
      expect( identification.exemplar_identification.active? ).to be false
    end

    it "sets active to false when identifications are not species" do
      observation = Observation.make!( taxon: species )
      identification = Identification.make!( observation: observation, taxon: species, body: "thebody" )
      expect( identification.exemplar_identification.active? ).to be true

      identification.update( taxon: genus )
      expect( identification.exemplar_identification.active? ).to be false
    end
  end

  describe "elastic indexing" do
    let( :genus ) { Taxon.make!( rank: Taxon::GENUS ) }
    let( :species ) { Taxon.make!( rank: Taxon::SPECIES, parent: genus ) }

    it "adds to index" do
      expect( ExemplarIdentification.elastic_search( where: {} ) ).to be_empty
      identification = Identification.make!( body: "thebody" )
      expect(
        ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } )
      ).not_to be_empty
    end

    it "removes from index" do
      expect( ExemplarIdentification.elastic_search( where: {} ) ).to be_empty
      identification = Identification.make!( body: "thebody" )
      expect( ExemplarIdentification.elastic_search( where: {} ) ).not_to be_empty
      expect(
        ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } )
      ).not_to be_empty

      identification.destroy
      expect( ExemplarIdentification.elastic_search( where: {} ) ).to be_empty
    end

    describe "identification updates" do
      it "updates the index when identifications are withdrawn" do
        expect( ExemplarIdentification.elastic_search( where: {} ) ).to be_empty
        observation = Observation.make!( taxon: species )
        identification = Identification.make!( observation: observation, body: "thebody", taxon: species )
        expect( ExemplarIdentification.elastic_search( where: {} ) ).not_to be_empty
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } )
        ).not_to be_empty
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } ).
            first["_source"]["active"]
        ).to be true

        identification.update( current: false )
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } ).
            first["_source"]["active"]
        ).to be false
      end
    end

    describe "observation updates" do
      it "updates the index when observations are modified" do
        expect( ExemplarIdentification.elastic_search( where: {} ) ).to be_empty
        original_observation_taxon = species
        observation = Observation.make!( taxon: species )
        identification = Identification.make!( observation: observation, body: "thebody", taxon: species )
        expect( ExemplarIdentification.elastic_search( where: {} ) ).not_to be_empty
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } )
        ).not_to be_empty
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } ).
            first["_source"]["identification"]["observation"]["taxon"]["id"]
        ).to eq original_observation_taxon.id

        new_observation_taxon = genus
        Identification.make!( observation: observation, taxon: genus, disagreement: true )
        expect( Observation.find( observation.id ).taxon ).to eq new_observation_taxon
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } ).
            first["_source"]["identification"]["observation"]["taxon"]["id"]
        ).to eq new_observation_taxon.id
      end

      it "updates the index when observation annotations are modified" do
        life_stage_attribute = make_controlled_term_with_label( "Life Stage" )
        larva = make_controlled_value_with_label( "Larva", life_stage_attribute )

        expect( ExemplarIdentification.elastic_search( where: {} ) ).to be_empty
        observation = Observation.make!( taxon: species )
        identification = Identification.make!( observation: observation, body: "thebody", taxon: species )
        expect( ExemplarIdentification.elastic_search( where: {} ) ).not_to be_empty
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } )
        ).not_to be_empty
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } ).
            first["_source"]["identification"]["observation"]["annotations"]
        ).to be_empty

        annotation = Annotation.make!(
          resource: identification.observation,
          controlled_attribute: life_stage_attribute,
          controlled_value: larva
        )
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } ).
            first["_source"]["identification"]["observation"]["annotations"]
        ).not_to be_empty

        annotation.vote_up( User.make! )
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } ).
            first["_source"]["identification"]["observation"]["annotations"]
        ).not_to be_empty

        annotation.vote_down( User.make! )
        annotation.vote_down( User.make! )
        expect(
          ExemplarIdentification.elastic_search( where: { "identification.id": identification.id } ).
            first["_source"]["identification"]["observation"]["annotations"]
        ).to be_empty
      end
    end
  end
end
