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
end
