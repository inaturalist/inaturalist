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

  it "renders hreflang alternate tags for each assigned locale" do
    assign( :taxon_hreflang_locales, ["fr", "de"] )
    render layout: "layouts/bootstrap", template: "taxa/show"
    expect( rendered ).to have_tag( "link[rel=alternate][hreflang=fr]" )
    expect( rendered ).to have_tag( "link[rel=alternate][hreflang=de]" )
    expect( rendered ).to have_tag( "link[rel=alternate][hreflang=x-default]" )
    expect( rendered ).to have_tag( "link[rel=alternate][hreflang=en]" )
  end

  it "renders no locale hreflang alternates when taxon_hreflang_locales is nil" do
    assign( :taxon_hreflang_locales, nil )
    render layout: "layouts/bootstrap", template: "taxa/show"
    expect( rendered ).not_to have_tag( "link[rel=alternate][hreflang=fr]" )
  end

  it "renders a locale canonical when url_locale is set" do
    assign( :url_locale, "fr" )
    assign( :taxon_hreflang_locales, ["fr"] )
    render layout: "layouts/bootstrap", template: "taxa/show"
    expect( rendered ).to have_tag( "link[rel=canonical][href*='/fr/taxa/']" )
  end

  it "renders the default canonical when url_locale is nil" do
    assign( :url_locale, nil )
    assign( :taxon_hreflang_locales, [] )
    render layout: "layouts/bootstrap", template: "taxa/show"
    expect( rendered ).to have_tag( "link[rel=canonical][href*='/taxa/']" )
    expect( rendered ).not_to have_tag( "link[rel=canonical][href*='/fr/taxa/']" )
  end
end
