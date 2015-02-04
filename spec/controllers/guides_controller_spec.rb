require File.dirname(__FILE__) + '/../spec_helper'

describe GuidesController, "import_taxa" do
  describe "from names" do
    before do
      @guide = Guide.make!
      sign_in @guide.user
    end
    it "should add guide taxa" do
      taxa = 3.times.map{Taxon.make!}
      @guide.guide_taxa.should be_blank
      post :import_taxa, id: @guide, names: taxa.map(&:name).join("\n"), format: :json
      @guide.reload
      @guide.guide_taxa.count.should eq 3
    end
  end
end