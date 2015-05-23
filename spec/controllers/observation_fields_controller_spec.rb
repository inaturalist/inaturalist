require File.dirname(__FILE__) + '/../spec_helper'

describe ObservationFieldsController do
  describe "destroy" do
    it "should not work if the field is in use" do
      of = ObservationField.make!
      ofv = ObservationFieldValue.make!(:observation_field => of)
      sign_in of.user
      delete :destroy, :id => of.id
      expect(ObservationField.where(:id => of.id).count).to eq 1
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
      expect(ObservationField.find_by_id(reject.id)).not_to be_blank
    end

    it "should destroy the primary resource" do
      sign_in user
      put :merge_field, :id => reject.id, :with => of.id
      expect(ObservationField.find_by_id(reject.id)).to be_blank
      expect(ObservationField.find_by_id(of.id)).not_to be_blank
    end

    it "should keep requested fields from the keeper" do
      sign_in user
      desc = "a perfectly unique description"
      of.update_attributes(:description => desc)
      put :merge_field, :id => reject.id, :with => of.id, :keep_description => 'keeper'
      of.reload
      expect(of.description).to eq desc
    end

    it "should keep requested fields from the reject" do
      sign_in user
      desc = "a perfectly unique description"
      reject.update_attributes(:description => desc)
      put :merge_field, :id => reject.id, :with => of.id, :keep_description => 'reject'
      of.reload
      expect(of.description).to eq desc
    end

    it "should allow merged allowed_values" do
      of.update_attributes(:allowed_values => 'a|b')
      reject.update_attributes(:allowed_values => 'c|d')
      sign_in user
      put :merge_field, :id => reject.id, :with => of.id, :keep_allowed_values => ['keeeper', 'reject']
      expect(ObservationField.find_by_id(reject.id)).to be_blank
      of.reload
      expect(of.allowed_values).to eq 'a|b|c|d'
    end
  end
end
