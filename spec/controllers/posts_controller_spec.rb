require File.dirname(__FILE__) + '/../spec_helper'

describe PostsController, "spam" do
  let(:spammer_content) { Post.make!(user: User.make!(spammer: true),
    parent: User.make!) }
  let(:flagged_content) {
    p = Post.make!(parent: User.make!)
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
