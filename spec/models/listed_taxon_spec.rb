require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ListedTaxon do
  it "should be invalid when check list fields set on a non-check list" do
    list = List.make
    check_list = CheckList.make
    listed_taxon = ListedTaxon.new(:list => list, :taxon => Taxon.make,
      :occurrence_status_level => ListedTaxon::OCCURRENCE_STATUS_LEVELS.keys.first)
    listed_taxon.should_not be_valid
    listed_taxon.list = check_list
    listed_taxon.should be_valid
  end
  
  describe "creation" do
    it "should update the species count on the list" do
      list = List.make
      species = Taxon.make(:rank => "species")
      list.species_count.should be(0)
      ListedTaxon.make(:list => list, :taxon => species)
      list.reload
      list.species_count.should be(1)
    end
  end
  
  describe "deletion" do
    it "should update the species count on the list" do
      species = Taxon.make(:rank => "species")
      listed_taxon = ListedTaxon.make(:taxon => species)
      list = listed_taxon.list
      
      expect {
        listed_taxon.destroy
        list.reload
      }.to change(list, :species_count).by(-1)
    end
  end
  
end