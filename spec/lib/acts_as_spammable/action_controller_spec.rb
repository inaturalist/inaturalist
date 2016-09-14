require "spec_helper"

describe ObservationsController, type: :controller do

  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }

  render_views
  let(:spammer) { User.make!(spammer: true) }
  let(:curator) { make_curator }
  let(:spammer_content) {
    o = Observation.make!
    o.user.update_attributes(spammer: true)
    o
  }
  let(:flagged_content) {
    o = Observation.make!
    Flag.make!(flaggable: o, flag: Flag::SPAM)
    o
  }

  it "normally renders 200" do
    get :show, id: Observation.make!.id
    expect(response.response_code).to eq 200
  end

  it "allows people that have entered some spam to view content normally" do
    sign_in flagged_content.user
    get :show, id: Observation.make!.id
    expect(response.response_code).to eq 200
  end

  it "returns a 403 when spammer content is viewed by average users" do
    get :show, id: spammer_content.id
    expect(response.response_code).to eq 403
    expect(response.body).to match /This user was suspended/
  end

  it "adds a flash message when spammer content is viewed by curators" do
    sign_in curator
    get :show, id: spammer_content.id
    expect(response.response_code).to eq 200
    expect(flash[:warning_title]).to eq "This has been flagged as spam"
  end

  it "returns a 403 when spam is viewed by average users" do
    get :show, id: flagged_content.id
    expect(response.response_code).to eq 403
    expect(response.body).to match /This has been flagged as spam/
  end

  it "adds a flash message when spam is viewed by curators" do
    sign_in curator
    get :show, id: flagged_content.id
    expect(response.response_code).to eq 200
    expect(flash[:warning_title]).to eq "This has been flagged as spam"
  end

  it "adds a flash message when spam is viewed by its owner" do
    sign_in flagged_content.user
    get :show, id: flagged_content.id
    expect(response.response_code).to eq 200
    expect(flash[:warning_title]).to eq "This has been flagged as spam"
  end

  it "spammers are suspended, so they will get recirected to a login page" do
    sign_in spammer
    get :show, id: flagged_content.id
    expect(response).to be_redirect
  end

end
