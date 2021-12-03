require File.dirname(__FILE__) + '/../spec_helper'

describe CheckListsController, "show" do
  before do
    load_test_taxa
    @list = CheckList.make!
    @lt_pregilla = ListedTaxon.make!(taxon: @Pseudacris_regilla, list: @list)
    @lt_canna = ListedTaxon.make!(taxon: @Calypte_anna, list: @list)
  end

  describe "occurrence_status filter" do
    before do
      @lt_canna.update(occurrence_status_level: ListedTaxon::ABSENT)
      @lt_canna.reload
      expect( @lt_canna ).to be_absent
    end

    it "should work for not_absent" do
      get :show, params: { id: @list.id, occurrence_status: "not_absent" }
      listed_taxa = assigns(:listed_taxa)
      expect( listed_taxa ).to include @lt_pregilla
      expect( listed_taxa ).not_to include @lt_canna
    end

    it "should work for any" do
      get :show, params: { id: @list.id, occurrence_status: "any" }
      listed_taxa = assigns(:listed_taxa)
      expect( listed_taxa ).to include @lt_pregilla
      expect( listed_taxa ).to include @lt_canna
    end

    it "should work for absent" do
      get :show, params: { id: @list.id, occurrence_status: "absent" }
      listed_taxa = assigns(:listed_taxa)
      expect( listed_taxa ).not_to include @lt_pregilla
      expect( listed_taxa ).to include @lt_canna
    end
  end
end

describe CheckListsController, "destroy" do
  it "should be allowed for curators if list is the default but place does not allow checklists" do
    place = create :place, :with_geom, prefers_check_lists: true
    list = place.check_list
    place.update( prefers_check_lists: false )
    curator = create :user, :as_curator
    sign_in curator
    delete :destroy, params: { id: list.id }
    expect( List.find_by_id( list.id ) ).to be_blank
  end

  it "should not be allowed for curators if list is the default and the place allows checklists" do
    place = create :place, :with_geom, prefers_check_lists: true
    list = place.check_list
    curator = create :user, :as_curator
    sign_in curator
    delete :destroy, params: { id: list.id }
    expect( List.find_by_id( list.id ) ).not_to be_blank
  end
end
