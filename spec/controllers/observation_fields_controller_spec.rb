require File.dirname(__FILE__) + '/../spec_helper'

describe ObservationFieldsController do
  describe "destroy" do
    it "should not work if the field is in use" do
      of = ObservationField.make!
      ofv = ObservationFieldValue.make!(:observation_field => of)
      sign_in of.user
      delete :destroy, :id => of.id
      ObservationField.where(:id => of.id).count.should eq 1
    end
  end

  describe "merge_field" do
    let(:user) { make_curator }
    let(:of) { ObservationField.make! }
    let(:reject) { ObservationField.make! }
    it "should only work for curators" do
      other_user = User.make!
      sign_in other_user
      put :merge_field, :id => of, :reject_id => reject.id
      ObservationField.find_by_id(reject.id).should_not be_blank
    end

    it "should destroy the primary resource" do
      sign_in user
      put :merge_field, :id => reject.id, :with => of.id
      ObservationField.find_by_id(reject.id).should be_blank
      ObservationField.find_by_id(of.id).should_not be_blank
    end

    it "should keep requested fields from the keeper" do
      sign_in user
      desc = "a perfectly unique description"
      of.update_attributes(:description => desc)
      put :merge_field, :id => reject.id, :with => of.id, :keep_description => 'keeper'
      of.reload
      of.description.should eq desc
    end

    it "should keep requested fields from the reject" do
      sign_in user
      desc = "a perfectly unique description"
      reject.update_attributes(:description => desc)
      put :merge_field, :id => reject.id, :with => of.id, :keep_description => 'reject'
      of.reload
      of.description.should eq desc
    end

    it "should allow merged allowed_values" do
      of.update_attributes(:allowed_values => 'a|b')
      reject.update_attributes(:allowed_values => 'c|d')
      sign_in user
      put :merge_field, :id => reject.id, :with => of.id, :keep_allowed_values => ['keeeper', 'reject']
      ObservationField.find_by_id(reject.id).should be_blank
      of.reload
      of.allowed_values.should eq 'a|b|c|d'
    end
  end
end