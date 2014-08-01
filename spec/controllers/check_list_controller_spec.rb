require File.dirname(__FILE__) + '/../spec_helper'

describe CheckListsController, "show" do
  before do
    load_test_taxa
    @list = CheckList.make!
    @lt_pregilla = ListedTaxon.make!(:taxon => @Pseudacris_regilla, :list => @list)
    @lt_canna = ListedTaxon.make!(:taxon => @Calypte_anna, :list => @list)
  end

  describe "occurrence_status filter" do
    before do
      @lt_canna.update_attributes(:occurrence_status_level => ListedTaxon::ABSENT)
      @lt_canna.reload
      @lt_canna.should be_absent
    end

    it "should work for not_absent" do
      get :show, :id => @list.id, :occurrence_status => "not_absent"
      listed_taxa = assigns(:listed_taxa)
      listed_taxa.should include @lt_pregilla
      listed_taxa.should_not include @lt_canna
    end

    it "should work for any" do
      get :show, :id => @list.id, :occurrence_status => "any"
      listed_taxa = assigns(:listed_taxa)
      listed_taxa.should include @lt_pregilla
      listed_taxa.should include @lt_canna
    end

    it "should work for absent" do
      get :show, :id => @list.id, :occurrence_status => "absent"
      listed_taxa = assigns(:listed_taxa)
      listed_taxa.should_not include @lt_pregilla
      listed_taxa.should include @lt_canna
    end
  end
end
