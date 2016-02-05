require File.dirname(__FILE__) + '/../spec_helper.rb'

describe PlaceTaxonName, "create_country_records_from_lexicons" do

  it "should add names in Chinese (traditional) to Taiwain" do
    taiwan = Place.make!(admin_level: Place::COUNTRY_LEVEL, name: 'Taiwan')
    tn = TaxonName.make!(lexicon: 'Chinese Traditional')
    tn.reload
    expect( tn.places ).to be_blank
    PlaceTaxonName.create_country_records_from_lexicons
    tn.reload
    expect( tn.places ).to include taiwan
  end

  it "should add names in German to Germany" do
    germany = Place.make!(admin_level: Place::COUNTRY_LEVEL, name: 'Germany')
    tn = TaxonName.make!(lexicon: 'german')
    expect( tn.places ).to be_blank
    PlaceTaxonName.create_country_records_from_lexicons
    tn.reload
    expect( tn.places ).to include germany
  end

  it "should add a German name to Germany even if another place taxon name exists" do
    germany = Place.make!(admin_level: Place::COUNTRY_LEVEL, name: 'Germany')
    austria = Place.make!(admin_level: Place::COUNTRY_LEVEL, name: 'Austria')
    tn = TaxonName.make!(lexicon: 'german')
    PlaceTaxonName.make!(place: austria, taxon_name: tn)
    tn.reload
    expect( tn.places ).to include austria
    PlaceTaxonName.create_country_records_from_lexicons
    tn.reload
    expect( tn.places ).to include germany
  end
  
end