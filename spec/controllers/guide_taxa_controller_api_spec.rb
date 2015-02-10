require File.dirname(__FILE__) + '/../spec_helper'

describe GuideTaxaController, "index" do
  before do
    @guide_photo = GuidePhoto.make!
    @guide_taxon = @guide_photo.guide_taxon
    @guide = @guide_photo.guide
  end

  it "should include guide photos" do
    get :index, :format => :json, :guide_id => @guide.id
    json = JSON.parse(response.body)
    expect(json['guide_taxa'][0]['guide_photos']).not_to be_blank
  end
end
