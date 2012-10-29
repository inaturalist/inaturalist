require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonStage, "commit" do
  before(:each) do
    @output_taxon = Taxon.make!(:is_active => false)
    @stage = TaxonStage.make
    @stage.add_output_taxon(@output_taxon)
    @stage.save!
  end

  it "should mark output taxon as active" do
    @output_taxon.should_not be_is_active
    @stage.commit
    @output_taxon.reload
    @output_taxon.should be_is_active
  end
end
