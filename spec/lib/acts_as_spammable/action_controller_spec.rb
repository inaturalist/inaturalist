require "spec_helper"

describe ObservationsController, type: :controller do

  render_views
  let(:spammer) { User.make!(spammer: true) }
  let(:spammer_content) { Observation.make!(user: spammer) }
  let(:flagged_content) {
    o = Observation.make!
    Flag.make!(flaggable: o, flag: Flag::SPAM)
    o
  }

  it "normally renders 200" do
    get :show, id: Observation.make!.id
    response.response_code.should == 200
  end

  it "allows people that have entered some spam to view content normally" do
    sign_in flagged_content.user
    get :show, id: Observation.make!.id
    response.response_code.should == 200
  end

  it "returns a 403 when the owner is a spammer" do
    get :show, id: spammer_content.id
    response.response_code.should == 403
    response.body.should match /Sorry, that doesn't exist/
  end

  it "returns a 403 when content is flagged as spam" do
    get :show, id: flagged_content.id
    response.response_code.should == 403
    response.body.should match /Sorry, that doesn't exist/
  end

  it "should render a special page when a user views their own spam" do
    sign_in flagged_content.user
    get :show, id: flagged_content.id
    response.response_code.should == 403
    response.body.should_not match /Sorry that doesn't exist/
    response.body.should match /Flagged as a violation of our/
  end

  it "spammers are suspended, so they will get recirected to a login page" do
    sign_in spammer
    get :show, id: flagged_content.id
    response.should be_redirect
  end

end
