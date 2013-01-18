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
    @taxon_link_for_tol.should be_valid
  end
  
  it "should apply to descendent taxa" do
    @taxon_link_for_tol.save
    TaxonLink.for_taxon(@child_taxon).should include(@taxon_link_for_tol)
  end
  
  it "should not allow a URL with ONLY [GENUS]" do
    @taxon_link_for_tol.url = "http://tolweb.org/[GENUS]"
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors[:url].should_not be_blank
  end
  
  it "should not allow a URL with ONLY [SPECIES]" do
    @taxon_link_for_tol.url = "http://tolweb.org/[SPECIES]"
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors[:url].should_not be_blank
  end
  
  it "should not allow invalid URLs" do
    @taxon_link_for_tol.url = "i am the very model of a modern major general"
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors[:url].should_not be_blank
  end
  
  it "should allow URLs with template tags" do
    @taxon_link_for_tol.should be_valid
    @taxon_link_for_tol.errors[:url].should be_blank
  end
  
  it "should not allow blank taxon_id" do
    @taxon_link_for_tol.taxon = nil
    @taxon_link_for_tol.should_not be_valid
    @taxon_link_for_tol.errors[:taxon_id].should_not be_blank
  end
  
  it "should set the site title from the URL" do
    @taxon_link_for_tol.site_title = nil
    @taxon_link_for_tol.save
    @taxon_link_for_tol.should be_valid
    @taxon_link_for_tol.site_title.should == 'tolweb.org'
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
    @taxon_link_with_genus_species.url_for_taxon(@Pseudacris_regilla).should =~ /Pseudacris/
  end
  
  it "should fill in [SPECIES]" do
    @taxon_link_with_genus_species.url_for_taxon(@Pseudacris_regilla).should =~ /regilla/
  end

  it "should fill in [GENUS] and [SPECIES]" do
    @taxon_link_with_genus_species.url_for_taxon(@Pseudacris_regilla).should == "http://tolweb.org/Pseudacris_regilla"
  end
  
  it "should fill in [NAME]" do
    @taxon_link_with_name.url_for_taxon(@Pseudacris).should == "http://tolweb.org/Pseudacris"
  end
  
  it "should fill in the taxon name when only [GENUS] and [SPECIES]" do
    @taxon_link_with_genus_species.url_for_taxon(@Pseudacris).should == "http://tolweb.org/Pseudacris"
  end

  it "should fill in [RANK]" do
    tl = TaxonLink.make!(:url => "http://www.foo.net/[RANK]/[NAME]", :site_title => "foo")
    tl.url_for_taxon(@Pseudacris_regilla).should eq("http://www.foo.net/species/Pseudacris regilla")
  end

  it "should fill in [NAME_WITH_RANK]" do
    t = Taxon.make!(:name => "Ensatina eschscholtzii xanthoptica", :rank => Taxon::SUBSPECIES)
    tl = TaxonLink.make!(:url => "http://www.foo.net/[NAME_WITH_RANK]", :site_title => "foo")
    tl.url_for_taxon(t).should eq("http://www.foo.net/Ensatina eschscholtzii ssp. xanthoptica")
  end
  
  it "should not alter a URL without template variables" do
    @taxon_link_without_template = TaxonLink.make!(
      :url => "http://amphibiaweb.org",
      :site_title => "AmphibiaWeb"
    )
    @taxon_link_without_template.url_for_taxon(Taxon.make!).should == @taxon_link_without_template.url
  end
end
