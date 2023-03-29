require File.dirname(__FILE__) + '/../spec_helper'

describe GuideTaxaController, "index" do
  elastic_models( Observation )
  
  before do
    @guide_photo = GuidePhoto.make!
    @guide_taxon = @guide_photo.guide_taxon
    @guide = @guide_photo.guide
  end

  it "should include guide photos" do
    get :index, format: :json, params: { guide_id: @guide.id }
    json = JSON.parse(response.body)
    expect(json['guide_taxa'][0]['guide_photos']).not_to be_blank
  end
end

describe GuideTaxaController, "show" do
  render_views
  let(:guide) { make_published_guide }
  let(:guide_taxon) { guide.guide_taxa.first }
  it "should include an absolute path to a stylesheet" do
    get :show, format: :xml, params: { id: guide_taxon.id }
    expect(response.body).to include ApplicationController.helpers.asset_url( "guide_taxon.xsl" )
  end
end
