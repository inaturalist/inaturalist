require File.dirname(__FILE__) + '/../spec_helper'

describe UsersController, "dashboard" do
  it "should be accessible when signed in" do
    user = User.make!
    sign_in user
    get :dashboard
    response.should be_success
  end
end

describe UsersController, "delete" do
  it "should be possible for the user" do
    user = User.make!
    sign_in user
    without_delay { delete :destroy, :id => user.id }
    response.should be_redirect
    User.find_by_id(user.id).should be_blank
  end
  
  it "should be impossible for everyone else" do
    user = User.make!
    nogoodnik = User.make!
    sign_in nogoodnik
    delete :destroy, :id => user.id
    User.find_by_id(user.id).should_not be_blank
  end
end

describe UsersController, "search" do
  it "should work while signed out" do
    get :search
    response.should be_success
  end
end

describe UsersController, "set_spammer" do
  describe "non-curators" do
    it "cannot access it" do
      post :set_spammer
      response.should be_redirect
      flash[:alert].should eq "You need to sign in or sign up before continuing."
    end
  end

  describe "curators" do
    before(:each) do
      @curator = make_curator
      http_login(@curator)
      request.env["HTTP_REFERER"] = "/"
    end

    it "can access it" do
      post :set_spammer
      response.should_not be_redirect
      flash[:alert].should be_blank
    end

    it "can set spammer to true" do
      @user = User.make!(spammer: nil)
      post :set_spammer, id: @user.id, spammer: "true"
      @user.reload
      @user.spammer.should be_true
    end

    it "removes spam flags when setting to non-spammer" do
      @user = User.make!(spammer: true)
      obs = Observation.make!(user: @user)
      Flag.make!(flaggable: obs, flag: Flag::SPAM)
      @user.spammer.should be_true
      @user.flags_on_spam_content.count.should == 1
      post :set_spammer, id: @user.id, spammer: "false"
      @user.reload
      @user.spammer.should be_false
      @user.flags_on_spam_content.count.should == 0
    end

  end
end

describe UsersController, "spam" do
  let(:spammer) { User.make!(spammer: true) }

  it "should render 403 when the user is a spammer" do
    get :show, id: spammer.id
    response.response_code.should == 403
  end
end
