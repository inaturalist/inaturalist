require File.dirname(__FILE__) + '/../spec_helper'

describe ListedTaxaController, "create" do
  render_views
  let(:user) { User.make! }
  let(:list) { List.make!(:user => user) }
  before do
    http_login(user)
  end

  it "should work" do
    taxon = Taxon.make!
    post :create, :format => :json, :listed_taxon => {:taxon_id => taxon.id, :list_id => list.id}
    list.listed_taxa.where(:taxon_id => taxon.id).should be_exists
  end
end
