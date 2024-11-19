require File.dirname(__FILE__) + '/../spec_helper.rb'

describe PlaceTaxonName do
  it { is_expected.to belong_to(:place).inverse_of :place_taxon_names }
  it { is_expected.to belong_to(:taxon_name).inverse_of :place_taxon_names }

  it { is_expected.to validate_presence_of :place }
  it { is_expected.to validate_presence_of :taxon_name }

  describe "create" do
    it "should set position relative to other records" do
      t = Taxon.make!
      tn1 = TaxonName.make!(name: "first", taxon: t)
      tn2 = TaxonName.make!(name: "second", taxon: t)
      tn3 = TaxonName.make!(name: "third", taxon: t)
      place = make_place_with_geom
      ptn1 = PlaceTaxonName.make!( place: place, taxon_name: tn1 )
      expect( ptn1.position ).to eq 1
      ptn2 = PlaceTaxonName.make!( place: place, taxon_name: tn2 )
      expect( ptn2.position ).to eq 2
      ptn3 = PlaceTaxonName.make!( place: make_place_with_geom, taxon_name: tn3 )
      expect( ptn3.position ).to eq 1
    end
  end

  describe "create_country_records_from_lexicons" do

    it "should add names in Chinese (traditional) to Taiwain" do
      taiwan = make_place_with_geom(admin_level: Place::COUNTRY_LEVEL, name: 'Taiwan')
      tn = TaxonName.make!(lexicon: 'Chinese Traditional')
      tn.reload
      expect( tn.places ).to be_blank
      PlaceTaxonName.create_country_records_from_lexicons
      tn.reload
      expect( tn.places ).to include taiwan
    end

    it "should add names in German to Germany" do
      germany = make_place_with_geom(admin_level: Place::COUNTRY_LEVEL, name: 'Germany')
      tn = TaxonName.make!(lexicon: 'german')
      expect( tn.places ).to be_blank
      PlaceTaxonName.create_country_records_from_lexicons
      tn.reload
      expect( tn.places ).to include germany
    end

    it "should add a German name to Germany even if another place taxon name exists" do
      germany = make_place_with_geom(admin_level: Place::COUNTRY_LEVEL, name: 'Germany')
      austria = make_place_with_geom(admin_level: Place::COUNTRY_LEVEL, name: 'Austria')
      tn = TaxonName.make!(lexicon: 'german')
      PlaceTaxonName.make!(place: austria, taxon_name: tn)
      tn.reload
      expect( tn.places ).to include austria
      PlaceTaxonName.create_country_records_from_lexicons
      tn.reload
      expect( tn.places ).to include germany
    end

  end
end
