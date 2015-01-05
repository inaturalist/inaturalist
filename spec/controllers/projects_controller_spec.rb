require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectsController, "spam" do
  let(:spammer_content) { Project.make!(user: User.make!(spammer: true)) }
  let(:flagged_content) {
    p = Project.make!
    Flag.make!(flaggable: p, flag: Flag::SPAM)
    p
  }

  it "should render 404 when the owner is a spammer" do
    get :show, id: spammer_content.id
    response.response_code.should == 404
  end

  it "should render 404 when content is flagged as spam" do
    get :show, id: spammer_content.id
    response.response_code.should == 404
  end
end
