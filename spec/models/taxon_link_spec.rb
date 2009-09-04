require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonLink, "creation" do
  fixtures :taxa
  before(:each) do
    @taxon_link_for_tol =  TaxonLink.new(
      :taxon => taxa(:Anura),
      :show_for_descendent_taxa => true,
      :url => "http://tolweb.org/[GENUS]_[SPECIES]",
      :site_title => "Tree of Life"
    )
  end
  
  it "should be valid" do
    @taxon_link_for_tol.should be_valid
  end
  
  it "should apply to descendent taxa" do
    @taxon_link_for_tol.save
    TaxonLink.for_taxon(taxa(:Pseudacris_regilla)).should include(@taxon_link_for_tol)
  end
  
  it "should not allow both [GENUS]/[SPECIES] and [NAME] in the url" do
    @taxon_link_for_tol.url = "http://tolweb.org/[GENUS]_[SPECIES]_[NAME]"
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors.on(:url).should_not be_nil
  end
  
  it "should not allow a URL with ONLY [GENUS]" do
    @taxon_link_for_tol.url = "http://tolweb.org/[GENUS]"
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors.on(:url).should_not be_nil
  end
  
  it "should not allow a URL with ONLY [SPECIES]" do
    @taxon_link_for_tol.url = "http://tolweb.org/[SPECIES]"
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors.on(:url).should_not be_nil
  end
  
  it "should not allow invalid URLs" do
    @taxon_link_for_tol.url = "i am the very model of a modern major general"
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors.on(:url).should_not be_nil
  end
  
  it "should allow URLs with template tags" do
    @taxon_link_for_tol.should be_valid
    @taxon_link_for_tol.errors.on(:url).should be_nil
  end
  
  it "should not allow blank taxon_id" do
    @taxon_link_for_tol.taxon = nil
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors.on(:taxon_id).should_not be_nil
  end
  
  it "should set the site title from the URL" do
    @taxon_link_for_tol.site_title = nil
    @taxon_link_for_tol.save
    @taxon_link_for_tol.should be_valid
    @taxon_link_for_tol.site_title.should == 'tolweb.org'
  end
end

describe TaxonLink, "url_for_taxon" do
  fixtures :taxa
  before(:each) do
    @taxon_link_with_genus_species =  TaxonLink.new(
      :taxon => taxa(:Anura),
      :show_for_descendent_taxa => true,
      :url => "http://tolweb.org/[GENUS]_[SPECIES]",
      :site_title => "Tree of Life"
    )
    
    @taxon_link_with_name =  TaxonLink.new(
      :taxon => taxa(:Anura),
      :show_for_descendent_taxa => true,
      :url => "http://tolweb.org/[NAME]",
      :site_title => "Tree of Life"
    )
  end
  
  it "should fill in [GENUS]" do
    @taxon_link_with_genus_species.url_for_taxon(
      taxa(:Pseudacris_regilla)).should =~ /Pseudacris/
  end
  
  it "should fill in [SPECIES]" do
    @taxon_link_with_genus_species.url_for_taxon(
      taxa(:Pseudacris_regilla)).should =~ /regilla/
  end

  it "should fill in [GENUS] and [SPECIES]" do
    @taxon_link_with_genus_species.url_for_taxon(
      taxa(:Pseudacris_regilla)
    ).should == "http://tolweb.org/Pseudacris_regilla"
  end
  
  it "should fill in [NAME]" do
    @taxon_link_with_name.url_for_taxon(
      taxa(:Pseudacris)
    ).should == "http://tolweb.org/Pseudacris"
  end
  
  it "should fill in the taxon name when only [GENUS] and [SPECIES]" do
    @taxon_link_with_genus_species.url_for_taxon(
      taxa(:Pseudacris)).should == "http://tolweb.org/Pseudacris"
  end
  
  it "should not alter a URL without template variables" do
    @taxon_link_without_template = TaxonLink.new(
      :taxon => taxa(:Amphibia),
      :url => "http://amphibiaweb.org",
      :site_title => "AmphibiaWeb"
    )
    @taxon_link_without_template.url_for_taxon(
      taxa(:Pseudacris)).should == @taxon_link_without_template.url
  end
end
