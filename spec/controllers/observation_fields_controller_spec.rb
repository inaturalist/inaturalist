require File.dirname(__FILE__) + '/../spec_helper'

describe ObservationFieldsController do
  describe :destroy do
    it "should not work if the field is in use" do
      of = ObservationField.make!
      ofv = ObservationFieldValue.make!(:observation_field => of)
      sign_in of.user
      delete :destroy, :id => of.id
      ObservationField.where(:id => of.id).count.should eq 1
    end
  end
end