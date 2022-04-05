# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe UsersController, "dashboard" do
  elastic_models( Observation )
  it "should be accessible when signed in" do
    user = User.make!
    sign_in user
    get :dashboard
    expect( response ).to be_successful
  end
  it "should show a site-specific announcement instead of a siteless one" do
    site = Site.make!
    a = Announcement.make!
    site_a = Announcement.make!
    site_a.sites << site
    u = User.make!( site: site )
    sign_in u
    get :dashboard, params: { inat_site_id: site.id }
    expect( assigns( :announcements ) ).to include site_a
    expect( assigns( :announcements ) ).not_to include a
  end
  it "should show a locale-specific announcement instead of a localeless one" do
    a = Announcement.make!
    locale_a = Announcement.make!( locales: ["es"] )
    u = User.make!( locale: "es" )
    sign_in u
    get :dashboard, params: { locale: "es" }
    expect( assigns( :announcements ) ).to include locale_a
    expect( assigns( :announcements ) ).not_to include a
  end
  it "should show a siteless, localeless announcement" do
    a = Announcement.make!
    sign_in User.make!
    get :dashboard
    expect( assigns( :announcements ) ).to include a
  end
  it "should show a siteless, localeless announcement even if the user has a site and a locale" do
    a = Announcement.make!
    site = Site.make!
    sign_in User.make!( locale: "es", site: site )
    get :dashboard, params: { inat_site_id: site.id }
    expect( assigns( :announcements ) ).to include a
  end
end

describe UsersController, "update" do
  let( :user ) { User.make! }
  before { sign_in user }

  it "changes updated_at when changing preferred_project_addition_by" do
    expect do
      put :update, params: { id: user.id, user: { preferred_project_addition_by: "none" } }
      user.reload
    end.to change( user, :updated_at )
  end
end

describe UsersController, "delete" do
  let( :user ) { User.make! }
  elastic_models( Observation )

  it "destroys in a delayed job" do
    sign_in user
    delete :destroy, params: { id: user.id, confirmation: user.login, confirmation_code: user.login }
    expect( Delayed::Job.where( "handler LIKE '%sane_destroy%'" ).count ).to eq 1
    expect( Delayed::Job.where( "unique_hash = '{:\"User::sane_destroy\"=>#{user.id}}'" ).
      count ).to eq 1
  end

  it "should be possible for the user" do
    sign_in user
    without_delay { delete :destroy, params: { id: user.id, confirmation: user.login, confirmation_code: user.login } }
    expect( response ).to be_redirect
    expect( User.find_by_id( user.id ) ).to be_blank
  end

  it "should be impossible for everyone else" do
    nogoodnik = User.make!
    sign_in nogoodnik
    delete :destroy, params: { id: user.id }
    expect( User.find_by_id( user.id ) ).not_to be_blank
  end
end

describe UsersController, "set_spammer" do
  elastic_models( Observation )

  describe "non-curators" do
    it "cannot access it" do
      post :set_spammer
      expect( response ).to be_redirect
      expect( flash[:alert] ).to eq "You need to sign in or sign up before continuing."
    end
  end

  describe "curators" do
    before( :each ) do
      @curator = make_curator
      sign_in( @curator )
      request.env["HTTP_REFERER"] = "/"
    end

    it "can access it" do
      post :set_spammer
      expect( response ).not_to be_redirect
      expect( flash[:alert] ).to be_blank
    end

    it "can set spammer to true" do
      @user = User.make!( spammer: nil )
      post :set_spammer, params: { id: @user.id, spammer: "true" }
      @user.reload
      expect( @user.spammer ).to be true
    end

    describe "when setting to non-spammer" do
      it "removes spam flags" do
        @user = User.make!
        obs = Observation.make!( user: @user )
        @user.update( spammer: true )
        Flag.make!( flaggable: obs, flag: Flag::SPAM )
        expect( @user.spammer ).to be true
        expect( @user.flags_on_spam_content.count ).to eq 1
        post :set_spammer, params: { id: @user.id, spammer: "false" }
        @user.reload
        expect( @user.spammer ).to be false
        expect( @user.flags_on_spam_content.count ).to eq 0
      end

      it "resolves spam flags" do
        o = Observation.make!
        f = Flag.make!( flaggable: o, flag: Flag::SPAM )
        expect( f ).not_to be_resolved
        post :set_spammer, params: { id: o.user_id, spammer: "false" }
        f.reload
        expect( f ).to be_resolved
      end

      it "marks the current user as the resolver" do
        o = Observation.make!
        f = Flag.make!( flaggable: o, flag: Flag::SPAM )
        post :set_spammer, params: { id: o.user_id, spammer: "false" }
        f.reload
        expect( f.resolver ).to eq @curator
      end
    end

    it "does not resolve spam flags when setting to spammer" do
      o = Observation.make!
      f = Flag.make!( flaggable: o, flag: Flag::SPAM )
      expect( f ).not_to be_resolved
      post :set_spammer, params: { id: o.user_id, spammer: "true" }
      f.reload
      expect( f ).not_to be_resolved
    end

    it "sets the user_id of the flag to the current_user" do
      u = User.make!
      post :set_spammer, params: { id: u.id, spammer: "true" }
      u.reload
      expect( u.flags.last.user ).to eq @curator
    end

    it "resolves the spam flag on the user when setting to non-spammer" do
      u = User.make!( spammer: true )
      post :set_spammer, params: { id: u.id, spammer: "true" }
      u.reload
      flag = u.flags.detect {| f | f.flag == Flag::SPAM }
      expect( flag ).not_to be_blank
      post :set_spammer, params: { id: u.id, spammer: "false" }
      flag.reload
      expect( flag ).to be_resolved
    end
  end
end

describe UsersController, "spam" do
  let( :spammer ) { User.make!( spammer: true ) }

  it "should render 403 when the user is a spammer" do
    get :show, params: { id: spammer.id }
    expect( response.response_code ).to eq 403
  end
end

describe UsersController, "update_session" do
  it "should set session attributes" do
    session[:prefers_observations_search_subview] = "list"
    get :update_session, params: { prefers_observations_search_subview: "grid" }
    expect( session[:prefers_observations_search_subview] ).to eq "grid"
  end

  it "should save preferences for logged in users" do
    user = User.make!( prefers_observations_search_subview: "list" )
    expect( user.prefers_observations_search_subview ).to eq "list"
    sign_in( user )
    get :update_session, params: { prefers_observations_search_subview: "grid" }
    user.reload
    expect( user.prefers_observations_search_subview ).to eq "grid"
  end
end

describe UsersController, "merge" do
  let( :normal_user ) { User.make! }
  let( :curator_user ) { make_curator }
  let( :admin_user ) { make_admin }
  let( :keeper_user ) { User.make!( login: "keeper", name: "keeper" ) }
  let( :reject_user ) { User.make!( login: "reject", name: "reject" ) }
  it "should not work for normal users" do
    sign_in normal_user
    after_delayed_job_finishes do
      expect do
        put :merge, params: { id: keeper_user.id, reject_user_id: reject_user.id }
      end.to throw_symbol( :abort )
    end
    expect( User.find_by_id( reject_user.id ) ).not_to be_blank
  end
  it "should not work for curators" do
    sign_in curator_user
    after_delayed_job_finishes do
      expect do
        put :merge, params: { id: keeper_user.id, reject_user_id: reject_user.id }
      end.to throw_symbol( :abort )
    end
    expect( User.find_by_id( reject_user.id ) ).not_to be_blank
  end
  it "should work for site admins" do
    sign_in admin_user
    after_delayed_job_finishes do
      put :merge, params: { id: keeper_user.id, reject_user_id: reject_user.id }
    end
    expect( User.find_by_id( reject_user.id ) ).to be_blank
  end
  describe "reindexing" do
    elastic_models( Project )
    it "should happen for projects the reject created" do
      proj = Project.make!( :collection, user: reject_user )
      es_proj = Project.elastic_search( where: { id: proj.id } ).results.results[0]
      proj_admin_user = User.find_by_id( es_proj.admins.first.user_id )
      expect( proj_admin_user ).to eq reject_user
      sign_in admin_user
      after_delayed_job_finishes do
        put :merge, params: { id: keeper_user.id, reject_user_id: reject_user.id }
      end
      expect( User.find_by_id( reject_user.id ) ).to be_blank
      es_proj = Project.elastic_search( where: { id: proj.id } ).results.results[0]
      proj_admin_user = User.find_by_id( es_proj.admins.first.user_id )
      expect( proj_admin_user ).to eq keeper_user
    end
  end
end

describe UsersController, "add_role" do
  let( :normal_user ) { User.make! }
  before { Role.make!( name: Role::CURATOR ) }
  it "should not work for a curator" do
    curator_user = make_curator
    sign_in curator_user
    put :add_role, params: { id: normal_user.id, role: Role::CURATOR }
    normal_user.reload
    expect( normal_user ).not_to be_is_curator
  end
  it "should work for a site_admin" do
    Site.make! if Site.default.blank?
    site = Site.make!
    sa = SiteAdmin.make!( site: site )
    normal_user.update!( site: site )
    sign_in sa.user
    put :add_role, params: { id: normal_user.id, role: Role::CURATOR }
    normal_user.reload
    expect( normal_user ).to be_is_curator
  end
  it "should set curator_sponsor to current user" do
    admin_user = make_admin
    sign_in admin_user
    put :add_role, params: { id: normal_user.id, role: Role::CURATOR }
    normal_user.reload
    expect( normal_user ).to be_is_curator
    expect( normal_user.curator_sponsor ).to eq admin_user
  end
end

describe UsersController, "remove_role" do
  let( :curator_user ) { make_curator }
  let( :target_curator_user ) { make_curator }
  it "should not work for a curator" do
    sign_in curator_user
    put :remove_role, params: { id: target_curator_user.id, role: Role::CURATOR }
    target_curator_user.reload
    expect( target_curator_user ).to be_is_curator
  end
  it "should work for a site_admin" do
    Site.make! if Site.default.blank?
    site = Site.make!
    sa = SiteAdmin.make!( site: site )
    target_curator_user.update!( site: site )
    sign_in sa.user
    put :remove_role, params: { id: target_curator_user.id, role: Role::CURATOR }
    target_curator_user.reload
    expect( target_curator_user ).not_to be_is_curator
  end
  it "should nilify curator_sponsor" do
    admin_user = make_admin
    sign_in admin_user
    put :remove_role, params: { id: curator_user.id, role: Role::CURATOR }
    updated_curator_user = User.find_by_id( curator_user.id )
    expect( updated_curator_user ).not_to be_is_curator
    expect( updated_curator_user.curator_sponsor ).to be_blank
  end
end

describe UsersController, "show" do
  it "should with a login" do
    u = User.make!
    get :show, params: { id: u.login }
    expect( assigns( :user ) ).to eq u
    expect( response ).to be_successful
  end
end

describe UsersController, "moderation" do
  let( :subject_user ) { User.make! }
  it "should be viewable by curators" do
    sign_in make_curator
    get :moderation, params: { id: subject_user.login }
    expect( response.response_code ).to eq 200
  end
  it "should not be viewable by non-curators" do
    sign_in User.make!
    get :moderation, params: { id: subject_user.login }
    expect( response.response_code ).not_to eq 200
  end
  it "should not be viewable by a curator if it's about the curator" do
    curator = make_curator
    sign_in curator
    get :moderation, params: { id: curator.login }
    expect( response.response_code ).not_to eq 200
  end
  it "should be viewable by an admin if it's about the admin" do
    admin = make_admin
    sign_in admin
    get :moderation, params: { id: admin.login }
    expect( response.response_code ).to eq 200
  end
end
