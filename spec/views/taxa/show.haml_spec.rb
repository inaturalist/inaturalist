# frozen_string_literal: true

require "spec_helper"

describe "taxa/show" do
  let( :taxon ) do
    parent = create( :taxon, :as_genus )
    create( :taxon, :as_species, parent: parent )
  end

  before do
    expect( taxon ).not_to be_is_iconic
    expect( taxon ).not_to be_root
    assign( :taxon, taxon )
    assign( :node_taxon_json, "" )
    assign( :site, create( :site ) )
  end

  it "renders a taxon with no common names" do
    expect( taxon.common_name ).to be_blank
    render layout: "layouts/bootstrap", template: "taxa/show"
    expect( rendered ).to have_tag( "title", text: /#{taxon.name}/ )
  end

  it "renders a taxon with a common name" do
    taxon_name = create( :taxon_name, lexicon: TaxonName::ENGLISH, taxon: taxon )
    taxon.reload
    expect( taxon.common_name ).not_to be_blank
    render layout: "layouts/bootstrap", template: "taxa/show"
    expect( rendered ).to have_tag( "title", text: /#{taxon_name.name}/ )
  end
end
