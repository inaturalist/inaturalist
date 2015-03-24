require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectUsersController, "update" do
  let(:project_user) { ProjectUser.make! }
  it "should set usage_according_to_project_terms" do
    expect(project_user).to be_prefers_usage_according_to_terms
    sign_in project_user.user
    patch :update, format: :json, id: project_user.id, project_user: {preferred_usage_according_to_terms: false}
    expect(response).to be_success
    project_user.reload
    expect(project_user).not_to be_prefers_usage_according_to_terms
  end
  it "should set project_post_updates" do
    expect(project_user).to be_prefers_updates
    sign_in project_user.user
    patch :update, format: :json, id: project_user.id, project_user: {preferred_updates: false}
    project_user.reload
    expect(project_user).not_to be_prefers_updates
  end
  it "should not allow you to update if you're not the right user" do
    expect(project_user).to be_prefers_usage_according_to_terms
    sign_in User.make!
    patch :update, format: :json, id: project_user.id, project_user: {preferred_usage_according_to_terms: false}
    project_user.reload
    expect(project_user).to be_prefers_usage_according_to_terms
  end
end
