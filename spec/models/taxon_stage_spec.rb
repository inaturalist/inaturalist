require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonStage, "commit" do
  before(:each) { prepare_stage }

  it "should mark output taxon as active" do
    @output_taxon.should_not be_is_active
    @stage.commit
    @output_taxon.reload
    @output_taxon.should be_is_active
  end
end

describe TaxonStage, "commit_records" do
  before(:each) { prepare_stage }
  it "should do no harm" do
    @stage.commit_records
  end
end

def prepare_stage
  @output_taxon = Taxon.make!(:is_active => false)
  @stage = TaxonStage.make
  @stage.add_output_taxon(@output_taxon)
  @stage.save!
end
