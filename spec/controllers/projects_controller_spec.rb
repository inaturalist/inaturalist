require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectsController, "spam" do
  let(:spammer_content) { Project.make!(user: User.make!(spammer: true)) }
  let(:flagged_content) {
    p = Project.make!
    Flag.make!(flaggable: p, flag: Flag::SPAM)
    p
  }

  it "should render 403 when the owner is a spammer" do
    get :show, id: spammer_content.id
    response.response_code.should == 403
  end

  it "should render 403 when content is flagged as spam" do
    get :show, id: spammer_content.id
    response.response_code.should == 403
  end
end
