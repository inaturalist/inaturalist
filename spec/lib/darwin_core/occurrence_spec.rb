require "spec_helper"

describe DarwinCore::Occurrence do
  it "should strip newlines from occurrenceRemarks" do
    o = Observation.make!( description: "here's a line\nand here's another\r\nand yet another\r" )
    expect( DarwinCore::Occurrence.adapt( o ).occurrenceRemarks ).to eq "here's a line and here's another and yet another"
  end

  it "should include stateProvince when available" do
    p = make_place_with_geom( admin_level: Place::STATE_LEVEL )
    o = Observation.make!( latitude: p.latitude, longitude: p.longitude )
    expect( DarwinCore::Occurrence.adapt( o ).stateProvince ).to eq p.name
  end

  it "should not include countryCode if coordinates are private" do
    p = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL, code: "USA" )
    o = Observation.make!( latitude: p.latitude, longitude: p.longitude, geoprivacy: Observation::PRIVATE )
    expect( DarwinCore::Occurrence.adapt( o ).countryCode ).to be_blank
  end

  it "should not include stateProvince if coordinates are private" do
    p = make_place_with_geom( admin_level: Place::STATE_LEVEL )
    o = Observation.make!( latitude: p.latitude, longitude: p.longitude, geoprivacy: Observation::PRIVATE )
    expect( DarwinCore::Occurrence.adapt( o ).stateProvince ).to be_blank
  end

  describe "identifier fields" do
    let(:pa) { ProviderAuthorization.make!( provider_name: "orcid", provider_uid: "0000-0001-0002-0003" ) }
    let(:o) { make_research_grade_candidate_observation }
    let(:genus) { Taxon.make!( rank: Taxon::GENUS ) }
    let(:species) { Taxon.make!( rank: Taxon::SPECIES, parent: genus ) }
    let(:improving_ident_genus) { Identification.make!( observation: o, taxon: genus ) }
    let(:improving_ident_species) { Identification.make!( observation: o, taxon: species, user: pa.user ) }
    let(:supporting_ident_species) { Identification.make!( observation: o, taxon: species ) }

    before do
      improving_ident_genus
      improving_ident_species
      supporting_ident_species
      # This is probably faster than using truncation
      Identification.update_categories_for_observation( o )
      improving_ident_genus.reload
      improving_ident_species.reload
      supporting_ident_species.reload
      o.reload
      expect( improving_ident_genus.category ).to eq Identification::IMPROVING
      expect( improving_ident_species.category ).to eq Identification::IMPROVING
      expect( supporting_ident_species.category ).to eq Identification::SUPPORTING
      expect( o.taxon_id ).to eq improving_ident_species.taxon_id
    end

    describe "identifiedByID" do
      it "should be the ORCID of the person who added the first improving identification that matches the obs taxon" do
        expect( improving_ident_species.user ).to eq pa.user
        expect( DarwinCore::Occurrence.adapt( o ).identifiedByID ).to include pa.provider_uid
      end
    end

    describe "identifiedBy" do
      it "should be the name of the person who added the first improving identification that matches the obs taxon" do
        expect( DarwinCore::Occurrence.adapt( o ).identifiedBy ).to eq improving_ident_species.user.name
      end

      it "should be the login of the person who added the first improving identification that matches the obs taxon if the name is blank" do
        pa.user.update_attributes( name: nil )
        expect( DarwinCore::Occurrence.adapt( o ).identifiedBy ).to eq improving_ident_species.user.login
      end
    end
  end

  describe "annotation fields" do
    def make_controlled_value_with_label( label )
      ct = ControlledTerm.make!(
        active: true,
        is_value: true
      )
      ct.labels << ControlledTermLabel.make!( label: label, controlled_term: ct )
      ControlledTermValue.make!(
        controlled_attribute: @controlled_attribute,
        controlled_value: ct
      )
      ct
    end
    describe "sex" do
      before(:all) do
        @controlled_attribute = ControlledTerm.make!(
          active: true,
          is_value: false
        )
        @controlled_attribute.labels << ControlledTermLabel.make!( label: "Sex", controlled_term: @controlled_attribute )
        @controlled_attribute
      end
      it "should be lowercase even if the annotation value is capitalized" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Female" )
        )
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).gbif_sex ).to eq "female"
      end
      it "should map Cannot Be Determined to undetermined" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Cannot Be Determined" )
        )
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).gbif_sex ).to eq "undetermined"
      end
      it "should not include a value that was voted down" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Female" )
        )
        annotation.vote_by voter: User.make!, vote: "bad"
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).gbif_sex ).to be_blank
      end
    end
    describe "lifeStage" do
      before(:all) do
        @controlled_attribute = ControlledTerm.make!(
          active: true,
          is_value: false
        )
        @controlled_attribute.labels << ControlledTermLabel.make!(
          label: "Life Stage",
          controlled_term: @controlled_attribute
        )
        @controlled_attribute
      end
      it "should leave nymph" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Nymph" )
        )
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).gbif_lifeStage ).to eq "nymph"
      end
      it "should leave larva" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Larva" )
        )
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).gbif_lifeStage ).to eq "larva"
      end
      it "ignores teneral" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Teneral" )
        )
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).gbif_lifeStage ).to be_blank
      end
      it "ignores subimago" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Subimago" )
        )
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).gbif_lifeStage ).to be_blank
      end
    end
    describe "reproductiveCondition" do
      before(:all) do
        @controlled_attribute = ControlledTerm.make!(
          active: true,
          is_value: false,
          multivalued: true
        )
        @controlled_attribute.labels << ControlledTermLabel.make!(
          label: "Plant Phenology",
          controlled_term: @controlled_attribute
        )
        @controlled_attribute
      end
      it "should add flowering for Plant Phenology=Flowering" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Flowering" )
        )
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).reproductiveCondition ).to eq "flowering"
      end
      it "should be blank for Plant Phenology=Cannot Be Determined" do
        annotation = Annotation.make!(
          resource: Observation.make!,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Cannot Be Determined" )
        )
        expect( DarwinCore::Occurrence.adapt( annotation.resource ).reproductiveCondition ).to be_blank
      end
      it "should concatenate multiple values with pipes" do
        obs = Observation.make!
        Annotation.make!(
          resource: obs,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Flowering" )
        )
        Annotation.make!(
          resource: obs,
          controlled_attribute: @controlled_attribute,
          controlled_value: make_controlled_value_with_label( "Fruiting" )
        )
        expect( DarwinCore::Occurrence.adapt( obs ).reproductiveCondition ).to eq "flowering|fruiting"
      end
    end
  end
end
