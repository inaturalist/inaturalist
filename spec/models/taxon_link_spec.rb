require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonLink do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :place }
  it { is_expected.to have_many(:comments).dependent :destroy }

  describe TaxonLink do
    let(:taxon) { create :taxon, :as_genus }
    let(:child_taxon) { create :taxon, :as_species, parent: taxon }

    let(:taxon_link_for_tol) do
      build :taxon_link,
        show_for_descendent_taxa: true,
        url: "http://tolweb.org/[GENUS]_[SPECIES]",
        site_title: "Tree of Life",
        taxon: taxon
    end

    describe "creation" do
      it "should apply to descendent taxa" do
        taxon_link_for_tol.save
        expect( TaxonLink.for_taxon( child_taxon ) ).to include( taxon_link_for_tol )
      end

      it "should set the site title from the URL" do
        taxon_link_for_tol.site_title = nil
        taxon_link_for_tol.save
        expect( taxon_link_for_tol ).to be_valid
        expect( taxon_link_for_tol.site_title ).to eq "tolweb.org"
      end
    end

    describe "validation" do
      it "should be valid" do
        expect( taxon_link_for_tol ).to be_valid
      end

      it "should not allow a URL with ONLY [GENUS]" do
        taxon_link_for_tol.url = "http://tolweb.org/[GENUS]"
        expect( taxon_link_for_tol ).to_not be_valid
        expect( taxon_link_for_tol.errors[:url] ).to_not be_blank
      end

      it "should not allow a URL with ONLY [SPECIES]" do
        taxon_link_for_tol.url = "http://tolweb.org/[SPECIES]"
        expect( taxon_link_for_tol ).to_not be_valid
        expect( taxon_link_for_tol.errors[:url] ).to_not be_blank
      end

      it "should not allow invalid URLs" do
        taxon_link_for_tol.url = "i am the very model of a modern major general"
        expect( taxon_link_for_tol ).to_not be_valid
        expect( taxon_link_for_tol.errors[:url] ).to_not be_blank
      end

      it "should allow URLs with template tags" do
        expect( taxon_link_for_tol ).to be_valid
        expect( taxon_link_for_tol.errors[:url] ).to be_blank
      end
    end
  end

  describe TaxonLink, "url_for_taxon" do
    let(:taxon_link_with_genus_species) do
      create :taxon_link,
        show_for_descendent_taxa: true,
        url: "http://inaturalist.org/[GENUS]_[SPECIES]",
        site_title: "Horror of Horrors"
    end

    let(:taxon_link_with_name) do
      create :taxon_link,
        show_for_descendent_taxa: true,
        url: "http://inaturalist.org/[NAME]",
        site_title: "Horror of Horrors"
    end
    let(:species) { build :taxon, :as_species }
    let(:genus) { build :taxon, :as_genus }

    it "should fill in [GENUS]" do
      genus = species.name.split.first
      expect( taxon_link_with_genus_species.url_for_taxon( species ) ).to include genus
    end

    it "should fill in [SPECIES]" do
      specific = species.name.split.last
      expect( taxon_link_with_genus_species.url_for_taxon( species ) ).to include specific
    end

    it "should fill in [GENUS] and [SPECIES]" do
      expect(
        taxon_link_with_genus_species.url_for_taxon( species )
      ).to include species.name.underscore.capitalize
    end

    it "should fill in [NAME]" do
      expect( taxon_link_with_name.url_for_taxon( genus ) ).to include genus.name
    end

    it "should fill in the taxon name when only [GENUS] and [SPECIES]" do
      expect( taxon_link_with_genus_species.url_for_taxon( genus ) ).to include genus.name
    end

    it "should fill in [RANK]" do
      tl = build :taxon_link, url: "http://www.foo.net/[RANK]/[NAME]"
      expect( tl.url_for_taxon( species ) ).to eq( "http://www.foo.net/species/#{species.name}")
    end

    it "should fill in [NAME_WITH_RANK]" do
      t = build :taxon, name: "Ensatina eschscholtzii xanthoptica", rank: Taxon::SUBSPECIES
      t.set_rank_level
      tl = build :taxon_link, url: "http://www.foo.net/[NAME_WITH_RANK]"
      expect( tl.url_for_taxon( t ) ).to eq "http://www.foo.net/Ensatina eschscholtzii ssp. xanthoptica"
    end

    it "should not include ranks above infraspecies level for [NAME_WITH_RANK]" do
      t = build :taxon, name: "Plethodontidae", rank: Taxon::FAMILY
      t.set_rank_level
      tl = build :taxon_link, url: "http://www.foo.net/[NAME_WITH_RANK]"
      expect( tl.url_for_taxon( t ) ).to eq "http://www.foo.net/Plethodontidae"
    end

    it "should not alter a URL without template variables" do
      tl = build :taxon_link, url: "http://amphibiaweb.org"
      expect( tl.url_for_taxon( build( :taxon ) ) ).to eq tl.url
    end

    it "should preserve spaces in [NAME]" do
      tl = build :taxon_link, url: "https://a.com/[NAME]"
      expect( tl.url_for_taxon( build( :taxon, :as_species ) ) ).to include " "
    end
    it "should use underscores in [NAME_]" do
      tl = build :taxon_link, url: "https://a.com/[NAME_]"
      expect( tl.url_for_taxon( build( :taxon, :as_species, name: "Foo bar" ) ) ).to include "Foo_bar"
      expect( tl.url_for_taxon( build( :taxon, :as_family, name: "Foobar" ) ) ).to include "Foobar"
    end
    it "should use dashes in [NAME-]" do
      tl = build :taxon_link, url: "https://a.com/[NAME-]"
      expect( tl.url_for_taxon( build( :taxon, :as_species, name: "Foo bar" ) ) ).to include "Foo-bar"
      expect( tl.url_for_taxon( build( :taxon, :as_family, name: "Foobar" ) ) ).to include "Foobar"
    end
  end
end
