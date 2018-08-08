require File.dirname(__FILE__) + '/../spec_helper'

describe UsersController, "dashboard" do
  before(:each) { enable_elastic_indexing(Observation) }
  after(:each) { disable_elastic_indexing(Observation) }
  it "should be accessible when signed in" do
    user = User.make!
    sign_in user
    get :dashboard
    expect(response).to be_success
  end
end

describe UsersController, "update" do
  let(:user) { User.make! }
  before { sign_in user }

  it "changes updated_at when changing preferred_project_addition_by" do
    expect {
      put :update, id: user.id, user: { preferred_project_addition_by: "none" }
      user.reload
    }.to change(user, :updated_at)
  end
end

describe UsersController, "delete" do
  let(:user) { User.make! }
  before(:each) { enable_elastic_indexing(Observation) }
  after(:each) { disable_elastic_indexing(Observation) }

  it "destroys in a delayed job" do
    sign_in user
    delete :destroy, id: user.id
    expect( Delayed::Job.where("handler LIKE '%sane_destroy%'").count ).to eq 1
    expect( Delayed::Job.where("unique_hash = '{:\"User::sane_destroy\"=>#{user.id}}'").
      count ).to eq 1
  end

  it "should be possible for the user" do
    sign_in user
    without_delay { delete :destroy, :id => user.id }
    expect(response).to be_redirect
    expect(User.find_by_id(user.id)).to be_blank
  end
  
  it "should be impossible for everyone else" do
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

  it "should results as json sorted by login" do
    User.make!(login: "aperson")
    User.make!(login: "person")
    get :search, format: :json
    results = JSON.parse(response.body)
    expect(response).to be_success
    expect(results[0]["login"]).to eq "aperson"
    expect(results[1]["login"]).to eq "person"
  end

  it "should return exact matches first" do
    User.make!(login: "aperson")
    User.make!(login: "person")
    get :search, format: :json, q: "person"
    results = JSON.parse(response.body)
    expect(response).to be_success
    expect(results[0]["login"]).to eq "person"
    expect(results[1]["login"]).to eq "aperson"
  end
end

describe UsersController, "set_spammer" do
  before(:each) { enable_elastic_indexing(Observation) }
  after(:each) { disable_elastic_indexing(Observation) }

  describe "non-curators" do
    it "cannot access it" do
      post :set_spammer
      expect(response).to be_redirect
      expect(flash[:alert]).to eq "You need to sign in or sign up before continuing."
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
      expect(response).not_to be_redirect
      expect(flash[:alert]).to be_blank
    end

    it "can set spammer to true" do
      @user = User.make!(spammer: nil)
      post :set_spammer, id: @user.id, spammer: "true"
      @user.reload
      expect(@user.spammer).to be true
    end

    it "removes spam flags when setting to non-spammer" do
      @user = User.make!
      obs = Observation.make!(user: @user)
      @user.update_attributes(spammer: true)
      Flag.make!(flaggable: obs, flag: Flag::SPAM)
      expect(@user.spammer).to be true
      expect(@user.flags_on_spam_content.count).to eq 1
      post :set_spammer, id: @user.id, spammer: "false"
      @user.reload
      expect(@user.spammer).to be false
      expect(@user.flags_on_spam_content.count).to eq 0
    end

    it "resolves spam flags when setting to non-spammer" do
      o = Observation.make!
      f = Flag.make!(flaggable: o, flag: Flag::SPAM)
      expect( f ).not_to be_resolved
      post :set_spammer, id: o.user_id, spammer: "false"
      f.reload
      expect( f ).to be_resolved
    end

    it "does not resolve spam flags when setting to spammer" do
      o = Observation.make!
      f = Flag.make!(flaggable: o, flag: Flag::SPAM)
      expect( f ).not_to be_resolved
      post :set_spammer, id: o.user_id, spammer: "true"
      f.reload
      expect( f ).not_to be_resolved
    end

    it "leaves resolver blank when resolving flags" do
      o = Observation.make!
      f = Flag.make!(flaggable: o, flag: Flag::SPAM)
      expect( f ).not_to be_resolved
      post :set_spammer, id: o.user_id, spammer: "false"
      f.reload
      expect( f.resolver ).to be_blank
    end

    it "sets the user_id of the flag to the current_user" do
      u = User.make!
      post :set_spammer, id: u.id, spammer: "true"
      u.reload
      expect( u.flags.last.user ).to eq @curator
    end

    it "resolves the spam flag on the user when setting to non-spammer" do
      u = User.make!( spammer: true )
      post :set_spammer, id: u.id, spammer: "true"
      u.reload
      flag = u.flags.detect{|f| f.flag == Flag::SPAM}
      expect( flag ).not_to be_blank
      post :set_spammer, id: u.id, spammer: "false"
      flag.reload
      expect( flag ).to be_resolved
    end
  end
end

describe UsersController, "spam" do
  let(:spammer) { User.make!(spammer: true) }

  it "should render 403 when the user is a spammer" do
    get :show, id: spammer.id
    expect(response.response_code).to eq 403
  end
end

describe UsersController, "update_session" do
  it "should set session attributes" do
    session[:prefers_observations_search_subview] = "list"
    get :update_session, prefers_observations_search_subview: "grid"
    expect( session[:prefers_observations_search_subview] ).to eq "grid"
  end

  it "should save preferences for logged in users" do
    user = User.make!(prefers_observations_search_subview: "list")
    expect(user.prefers_observations_search_subview).to eq "list"
    http_login(user)
    get :update_session, prefers_observations_search_subview: "grid"
    user.reload
    expect(user.prefers_observations_search_subview).to eq "grid"
  end
end

describe UsersController, "merge" do
  let(:normal_user) { User.make! }
  let(:curator_user) { make_curator }
  let(:admin_user) { make_admin }
  let(:keeper_user) { User.make! }
  let(:reject_user) { User.make! }
  it "should not work for normal users" do
    sign_in normal_user
    put :merge, id: keeper_user.id, reject_user_id: reject_user.id
    expect( User.find_by_id( reject_user.id ) ).not_to be_blank
  end
  it "should not work for curators" do
    sign_in curator_user
    put :merge, id: keeper_user.id, reject_user_id: reject_user.id
    expect( User.find_by_id( reject_user.id ) ).not_to be_blank
  end
  it "should work for site admins" do
    sign_in admin_user
    put :merge, id: keeper_user.id, reject_user_id: reject_user.id
    expect( User.find_by_id( reject_user.id ) ).to be_blank
  end
end

describe UsersController, "add_role" do
  it "should set curator_sponsor to current user" do
    curator_user = make_curator
    normal_user = User.make!
    sign_in curator_user
    put :add_role, id: normal_user.id, role: "curator"
    normal_user.reload
    expect( normal_user ).to be_is_curator
    expect( normal_user.curator_sponsor ).to eq curator_user
  end
end

describe UsersController, "remove_role" do
  it "should nilify curator_sponsor" do
    curator_user = make_curator
    admin_user = make_admin
    sign_in admin_user
    put :remove_role, id: curator_user.id, role: "curator"
    curator_user.reload
    expect( curator_user ).not_to be_is_curator
    expect( curator_user.curator_sponsor ).to be_blank
  end
end

describe UsersController, "suspend" do
  let(:user) { User.make! }
  let(:curator_user) { make_curator }
  it "suspends the user" do
    expect( user.suspended_at ).to be_nil
    sign_in curator_user
    get :suspend, id: user.id
    user.reload
    expect( user.suspended_at ).not_to be_nil
  end

  it "sets the suspending user" do
    expect( user.suspended_at ).to be_nil
    sign_in curator_user
    get :suspend, id: user.id
    user.reload
    expect( user.suspended_by_user ).to eq curator_user
  end
end

describe UsersController, "unsuspend" do
  let(:user) { User.make!( suspended_at: Time.now ) }
  let(:curator_user) { make_curator }
  it "unsuspends the user" do
    expect( user.suspended_at ).not_to be_nil
    sign_in curator_user
    get :unsuspend, id: user.id
    user.reload
    expect( user.suspended_at ).to be_nil
  end

  it "unsets the suspending user" do
    expect( user.suspended_at ).not_to be_nil
    sign_in curator_user
    get :unsuspend, id: user.id
    user.reload
    expect( user.suspended_by_user ).to be_nil
  end
end
