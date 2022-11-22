# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuideTaxon do
  it { is_expected.to belong_to(:guide).inverse_of :guide_taxa }
  it { is_expected.to belong_to(:taxon).inverse_of :guide_taxa }
  it { is_expected.to have_one(:user).through :guide }
  it { is_expected.to have_many(:guide_sections).inverse_of(:guide_taxon).dependent :delete_all }
  it { is_expected.to have_many(:guide_photos).inverse_of(:guide_taxon).dependent :delete_all }
  it { is_expected.to have_many(:guide_ranges).inverse_of(:guide_taxon).dependent :delete_all }
  it { is_expected.to have_many(:photos).through :guide_photos }

  it { is_expected.to validate_presence_of :guide }
  it { is_expected.to validate_presence_of :taxon }

  describe "creation" do
    let(:genus) { build :taxon, :as_genus }
    let(:species) { build :taxon, :as_species, wikipedia_summary: "foo bar" }
    let(:guide) { create :guide }
    let(:subject) { create :guide_taxon, taxon: species }

    it "should add the taxon's wikipedia description as a GuideSection" do
      expect(subject.guide_sections).not_to be_blank
      expect(subject.guide_sections.first.description).to eq(species.wikipedia_summary)
    end

    it "should set the license for the default GuideSection to CC-BY-SA" do
      expect(subject.guide_sections.first.license).to eq(Observation::CC_BY_SA)
    end

    it "should update the guide's taxon id" do
      genus.save

      without_delay { create :guide_taxon, guide: guide, taxon: (create :taxon, :as_species, parent: genus) }
      without_delay { create :guide_taxon, guide: guide, taxon: (create :taxon, :as_species, parent: genus) }

      expect { guide.reload }.to change { guide.taxon_id }.from(nil).to(genus.id)
    end

    describe "#within_count_limit" do
      subject { build :guide_taxon }

      let(:guide) { subject.guide }
      let(:count) { 500 }

      before { allow(guide).to receive_message_chain(:guide_taxa, :count).and_return count }

      describe "should not be able to create more than 500 guide taxa per guide" do
        it { is_expected.to_not be_valid }

        it "should have error" do
          expect(subject.tap(&:valid?).errors.messages[:base]).to include I18n.t(
            "activerecord.errors.models.guide_taxon.attributes.base.guide_has_too_many_taxa"
          )
        end
      end

      describe "should be able to create up to 500 guide taxa per guide" do
        let(:count) { 499 }

        it { is_expected.to be_valid }
      end
    end
  end

  describe "deletion" do
    it "should update the guide's taxon id" do
      without_delay do
        g = Guide.make!
        ancestor = Taxon.make!(rank: Taxon::GENUS)
        t1 = Taxon.make!(parent: ancestor, rank: Taxon::SPECIES)
        t2 = Taxon.make!
        gt1 = GuideTaxon.make!(:guide => g, :taxon => t1)
        gt2 = GuideTaxon.make!(:guide => g, :taxon => t2)
        g.reload
        expect(g.taxon_id).to be_blank
        gt2.destroy
        g.reload
        expect(g.taxon_id).to eq t1.parent_id
      end
    end
  end

  describe "sync_site_content" do
    elastic_models( Observation )
    let(:t) {
      t = Taxon.make!(:wikipedia_summary => "Foo bar")
      6.times do
        p = Photo.make!(:license => Photo::CC_BY)
        TaxonPhoto.make!(:taxon => t, :photo => p)
      end
      TaxonName.make!(:taxon => t, :lexicon => "English")
      t.reload
      t
    }
    let(:gt) { GuideTaxon.make!(:taxon => t) }

    it "should set up to 5 photos" do
      expect(gt.taxon.photos.size).to be > 5
      gt.sync_site_content(:photos => true)
      expect(gt.guide_photos.size).to eq 5
    end

    it "should set a common name" do
      gt.update(:display_name => nil)
      expect(gt.display_name).to be_blank
      gt.sync_site_content(:names => true)
      expect(gt.display_name).to eq gt.taxon.common_name.name
    end

    it "should set a section" do
      gt.guide_sections.destroy_all
      expect(gt.guide_sections).to be_blank
      gt.sync_site_content(:summary => true)
      expect(gt.guide_sections.size).to eq 1
    end
  end

  describe "sync_eol" do
    let(:gt) { GuideTaxon.make! }
    elastic_models( Observation )
    before(:all) do
      Site.make!
      eol = EolService.new(:timeout => 30)
      @mflagellum_page ||= eol.page( 47046719,
                                     common_names: true,
                                     images_per_page: 5,
                                     maps_per_page: 5,
                                     texts_per_page: 5,
                                     details: true,
                                     cache_ttl: -1
      )
    end

    it "should update the display_name" do
      expect( gt.display_name.to_s.downcase ).not_to eq "coachwhip"
      gt.sync_eol(:page => @mflagellum_page, :replace => true)
      expect( gt.display_name.to_s.downcase ).to eq "coachwhip"
    end

    it "should allow replacement of existing content" do
      gp = GuidePhoto.make!(:guide_taxon => gt)
      gr = GuideRange.make!(:guide_taxon => gt)
      gs = GuideSection.make!(:guide_taxon => gt)
      gt.sync_eol(:page => @mflagellum_page, :replace => true, :photos => true, :ranges => true, :overview => true)
      expect(GuidePhoto.find_by_id(gp.id)).to be_blank
      expect(GuideRange.find_by_id(gr.id)).to be_blank
      expect(GuideSection.find_by_id(gs.id)).to be_blank
    end

    it "should not replace existing content if not requested" do
      original_name = "foo1"
      gt.update(:display_name => original_name)
      gp = GuidePhoto.make!(:guide_taxon => gt)
      gr = GuideRange.make!(:guide_taxon => gt)
      gs = GuideSection.make!(:guide_taxon => gt)
      gt.sync_eol(:page => @mflagellum_page, :photos => true, :ranges => true, :overview => true)
      gt.reload
      expect(gt.display_name).to eq original_name
      expect(GuidePhoto.find_by_id(gp.id)).not_to be_blank
      expect(GuideRange.find_by_id(gr.id)).not_to be_blank
      expect(GuideSection.find_by_id(gs.id)).not_to be_blank
    end

    it "should not add content for categories that weren't selected" do
      gt.guide_photos.destroy_all
      gt.guide_sections.destroy_all
      gt.guide_ranges.destroy_all
      expect(gt.guide_photos.count).to eq 0
      expect(gt.guide_sections.count).to eq 0
      expect(gt.guide_ranges.count).to eq 0
      gt.sync_eol(:page => @mflagellum_page, :photos => "0", :ranges => "0", :overview => "0")
      gt.reload
      expect(gt.guide_photos.count).to eq 0
      expect(gt.guide_sections.count).to eq 0
      expect(gt.guide_ranges.count).to eq 0
    end

    it "should add at least one secion if overview requested" do
      expect(gt.guide_sections).to be_blank
      gt.sync_eol(:page => @mflagellum_page, :overview => true)
      gt.reload
      expect(gt.guide_sections).not_to be_blank
    end

    # this doesn't pass b/c EOL's page api seems to return a GeneralDescription
    # when you request a Description. Could hack around it, of course, but would
    # rather the EOL API just behaved reasonably
    # it "should add a description section if requested" do
    #   expect(gt.guide_sections).to be_blank
    #   eol = EolService.new(:timeout => 30)
    #   page = eol.page(577775, :subjects => "Description")
    #   gt.sync_eol(:page => page, :subjects => %w(Description))
    #   gt.reload
    #   expect(gt.guide_sections).not_to be_blank
    # end
  end

  describe "sync_eol_photos" do
    let(:gt) { GuideTaxon.make! }
    elastic_models( Observation )
    before(:all) do
      eol = EolService.new(:timeout => 30)
      @mflagellum_page ||= eol.page( 47046719,
                                     common_names: true,
                                     images_per_page: 5,
                                     maps_per_page: 5,
                                     texts_per_page: 5,
                                     details: true,
                                     cache_ttl: -1
      )
    end

    it "should add new photos" do
      expect(gt.guide_photos).to be_blank
      gt.sync_eol_photos(:page => @mflagellum_page)
      gt.save!
      gt.reload
      expect(gt.guide_photos).not_to be_blank
    end

    it "should not add duplicate photos" do
      gt.sync_eol_photos(:page => @mflagellum_page)
      gt.save!
      s1 = gt.guide_photos.size
      gt.sync_eol_photos(:page => @mflagellum_page)
      gt.save!
      gt.reload
      s2 = gt.guide_photos.size
      expect(s2).to eq s1
    end

    it "should position new photos after existing ones" do
      gp = GuidePhoto.make!(:guide_taxon => gt)
      gt.sync_eol_photos(:page => @mflagellum_page)
      gt.save!
      gt.reload
      guide_photos = gt.guide_photos.sort_by(&:position)
      expect(guide_photos.first).to eq gp
      expect(guide_photos.last.position).to be > gp.position
    end

    # it "should not add maps" do
    #   page = EolService.page(791500, :common_names => true, :maps => 1, :details => true, :photos => 0)
    #   gt.sync_eol_photos(:page => page)
    #   if gp = gt.guide_photos.last
    #     puts "gp.attributes: #{gp.attributes.inspect}"
    #   end
    #   expect(gt.guide_photos).to be_blank
    # end
  end

  describe "add_color_tags" do
    let(:yellow) { build :color, value: "yellow" }
    let(:blue) { build :color, value: "blue" }
    let(:taxon) { build :taxon, colors: [yellow, blue] }
    let(:subject) { build :guide_taxon, taxon: taxon }

    before { subject.add_color_tags }

    it "should add tags" do
      expect(subject.tag_list).to include("color=yellow")
      expect(subject.tag_list).to include("color=blue")
    end
  end

  describe "add_rank_tag" do

    before do
      @genus = Taxon.make!(:rank => "genus")
      @tn = @genus.taxon_names.create(:lexicon => TaxonName::LEXICONS[:ENGLISH], :name => "Fulminator")
      @t = Taxon.make!(:rank => "species", :parent => @genus)
      @gt = GuideTaxon.make!(:taxon => @t)
    end

    it "should add tags" do
      expect(@genus.taxon_names.count).to eq 2
      @gt.add_rank_tag('genus', :lexicon => TaxonName::LEXICONS[:ENGLISH])
      expect(@gt.tag_list).to include("taxonomy:genus=#{@tn.name}")
    end

    it "should work for rank names that collide with keywords" do
      load_test_taxa
      gt = GuideTaxon.make!(:taxon => @Pseudacris_regilla)
      gt.add_rank_tag('order')
      expect(gt.tag_list).to include "taxonomy:order=Anura"
    end
  end
end
