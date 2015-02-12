require File.dirname(__FILE__) + '/../spec_helper'

describe UsersController, "dashboard" do
  it "should be accessible when signed in" do
    user = User.make!
    sign_in user
    get :dashboard
    expect(response).to be_success
  end
end

describe UsersController, "delete" do
  it "should be possible for the user" do
    user = User.make!
    sign_in user
    without_delay { delete :destroy, :id => user.id }
    expect(response).to be_redirect
    expect(User.find_by_id(user.id)).to be_blank
  end
  
  it "should be impossible for everyone else" do
    user = User.make!
    nogoodnik = User.make!
    sign_in nogoodnik
    delete :destroy, :id => user.id
    expect(User.find_by_id(user.id)).not_to be_blank
  end
end

describe UsersController, "search" do
  it "should work while signed out" do
    get :search
    expect(response).to be_success
  end
end

describe UsersController, "spam" do
  let(:spammer) { User.make!(spammer: true) }

  it "should render 403 when the user is a spammer" do
    get :show, id: spammer.id
    expect(response.response_code).to eq 403
  end
end
