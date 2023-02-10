require File.dirname(__FILE__) + '/../spec_helper.rb'

describe List do
  elastic_models( Observation, Place )

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :place }
  it { is_expected.to have_one(:check_list_place).class_name("Place").with_foreign_key :check_list_id }
  it { is_expected.to have_many(:rules).class_name("ListRule").dependent :destroy }
  it { is_expected.to have_many(:listed_taxa).dependent :destroy }
  it { is_expected.to have_many(:taxa).through :listed_taxa }

  it { is_expected.to validate_presence_of :title }

  describe "updating" do
    it "should not be allowed anyone other than the owner" do
      list = List.make!
      other_user = User.make!
      expect(list).to be_editable_by list.user
      expect(list).not_to be_editable_by other_user
    end
  end

  # Note: List#refresh is pretty thoroughly tested by the Observation 
  # spec, so these will remain unimplemented.  I couldn't figure out how to
  # test them without touching observations anyway (KMU 2008-12-5)
  describe "refreshing" do
    it "should update all last_observations in the list"
    it "should destroy all invalid listed taxa"
    it "should restrict its updates to the taxa param passed in"
  end

  describe "taxon adding" do
  
    it "should return a ListedTaxon" do
      list = List.make!
      taxon = Taxon.make!
      expect(list.add_taxon(taxon)).to be_a(ListedTaxon)
    end
  
    it "should not create a new ListedTaxon if the taxon is already in the list" do
      listed_taxon = ListedTaxon.make!
      list = listed_taxon.list
      taxon = listed_taxon.taxon
      new_listed_taxon = list.add_taxon(taxon)
      expect(new_listed_taxon).not_to be_valid
    end
  
  end

  describe "rank rules" do
    let(:list) { List.make! }
    let(:genus) { Taxon.make!(name: 'Foo', rank: 'genus')}
    let(:species) { Taxon.make!(rank: 'species')}
    it "should default to any" do
      expect(list.rank_rule).to eq 'any'
    end
    it "should not refresh the list when changed" do
      list.add_taxon(genus, manually_added: true)
      list.add_taxon(species, manually_added: true)
      without_delay do
        expect {
          list.update(rank_rule: "species?")
        }.to change(list.listed_taxa, :count).by(0)
      end
    end
    it "should not remove genera when changed to species-only" do
      list.add_taxon(genus, manually_added: true)
      list.add_taxon(species, manually_added: true)
      without_delay do
        list.update(rank_rule: "species?")
        expect(list.taxa).to include genus
      end
    end
  end

end
