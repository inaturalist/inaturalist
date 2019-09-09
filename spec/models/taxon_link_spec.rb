require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonLink, "creation" do

  before(:each) do
    @taxon_link_for_tol = TaxonLink.make!(
      :show_for_descendent_taxa => true,
      :url => "http://tolweb.org/[GENUS]_[SPECIES]",
      :site_title => "Tree of Life"
    )
    @taxon = @taxon_link_for_tol.taxon
    @child_taxon = Taxon.make!
    @child_taxon.update_attributes(:parent => @taxon)
  end
  
  it "should be valid" do
    expect( @taxon_link_for_tol ).to be_valid
  end
  
  it "should apply to descendent taxa" do
    @taxon_link_for_tol.save
    expect( TaxonLink.for_taxon(@child_taxon) ).to include(@taxon_link_for_tol)
  end
  
  it "should not allow a URL with ONLY [GENUS]" do
    @taxon_link_for_tol.url = "http://tolweb.org/[GENUS]"
    expect( @taxon_link_for_tol ).to_not be_valid
    expect( @taxon_link_for_tol.errors[:url] ).to_not be_blank
  end
  
  it "should not allow a URL with ONLY [SPECIES]" do
    @taxon_link_for_tol.url = "http://tolweb.org/[SPECIES]"
    expect( @taxon_link_for_tol ).to_not be_valid
    expect( @taxon_link_for_tol.errors[:url] ).to_not be_blank
  end
  
  it "should not allow invalid URLs" do
    @taxon_link_for_tol.url = "i am the very model of a modern major general"
    expect( @taxon_link_for_tol ).to_not be_valid
    expect( @taxon_link_for_tol.errors[:url] ).to_not be_blank
  end
  
  it "should allow URLs with template tags" do
    expect( @taxon_link_for_tol ).to be_valid
    expect( @taxon_link_for_tol.errors[:url] ).to be_blank
  end
  
  it "should not allow blank taxon_id" do
    @taxon_link_for_tol.taxon = nil
    expect( @taxon_link_for_tol ).to_not be_valid
    expect( @taxon_link_for_tol.errors[:taxon_id] ).to_not be_blank
  end
  
  it "should set the site title from the URL" do
    @taxon_link_for_tol.site_title = nil
    @taxon_link_for_tol.save
    expect( @taxon_link_for_tol ).to be_valid
    expect( @taxon_link_for_tol.site_title ).to eq 'tolweb.org'
  end
end

describe TaxonLink, "url_for_taxon" do
  before(:all) do
    load_test_taxa
  end
  before(:each) do
    @taxon_link_with_genus_species = TaxonLink.make!(
      :show_for_descendent_taxa => true,
      :url => "http://tolweb.org/[GENUS]_[SPECIES]",
      :site_title => "Tree of Life"
    )
    
    @taxon_link_with_name = TaxonLink.make!(
      :show_for_descendent_taxa => true,
      :url => "http://tolweb.org/[NAME]",
      :site_title => "Tree of Life"
    )
  end
  
  it "should fill in [GENUS]" do
    expect( @taxon_link_with_genus_species.url_for_taxon(@Pseudacris_regilla) ).to be =~ /Pseudacris/
  end
  
  it "should fill in [SPECIES]" do
    expect( @taxon_link_with_genus_species.url_for_taxon(@Pseudacris_regilla) ).to be =~ /regilla/
  end

  it "should fill in [GENUS] and [SPECIES]" do
    expect( @taxon_link_with_genus_species.url_for_taxon(@Pseudacris_regilla) ).to eq "http://tolweb.org/Pseudacris_regilla"
  end
  
  it "should fill in [NAME]" do
    expect( @taxon_link_with_name.url_for_taxon(@Pseudacris) ).to eq "http://tolweb.org/Pseudacris"
  end
  
  it "should fill in the taxon name when only [GENUS] and [SPECIES]" do
    expect( @taxon_link_with_genus_species.url_for_taxon(@Pseudacris) ).to eq "http://tolweb.org/Pseudacris"
  end

  it "should fill in [RANK]" do
    tl = TaxonLink.make!(:url => "http://www.foo.net/[RANK]/[NAME]", :site_title => "foo")
    expect( tl.url_for_taxon(@Pseudacris_regilla) ).to eq("http://www.foo.net/species/Pseudacris regilla")
  end

  it "should fill in [NAME_WITH_RANK]" do
    t = Taxon.make!(:name => "Ensatina eschscholtzii xanthoptica", :rank => Taxon::SUBSPECIES)
    tl = TaxonLink.make!(:url => "http://www.foo.net/[NAME_WITH_RANK]", :site_title => "foo")
    expect( tl.url_for_taxon(t) ).to eq("http://www.foo.net/Ensatina eschscholtzii ssp. xanthoptica")
  end

  it "should not include ranks above infraspecies level for [NAME_WITH_RANK]" do
    t = Taxon.make!( name: "Plethodontidae", rank: Taxon::FAMILY )
    tl = TaxonLink.make!( url: "http://www.foo.net/[NAME_WITH_RANK]", site_title: "foo" )
    expect( tl.url_for_taxon( t ) ).to eq( "http://www.foo.net/Plethodontidae" )
  end
  
  it "should not alter a URL without template variables" do
    @taxon_link_without_template = TaxonLink.make!(
      :url => "http://amphibiaweb.org",
      :site_title => "AmphibiaWeb"
    )
    expect( @taxon_link_without_template.url_for_taxon(Taxon.make!) ).to eq @taxon_link_without_template.url
  end
end
