# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

# Be sure to include AuthenticatedTestHelper in spec/spec_helper.rb instead.
# Then, you can remove it from this and the functional test.
include AuthenticatedTestHelper

bad_logins = [
  '12', '123', '1234567890_234567890_234567890_234567890_',
  "Iñtërnâtiônàlizætiøn hasn't happened to ruby 1.8 yet",
  'semicolon;', 'quote"', 'tick\'', 'backtick`', 'percent%', 'plus+', 
  'period.', 'm', 
  'this_is_the_longest_login_ever_written_by_man',
  "password",
  "new",
  "[foo",
  "^foo"
]

describe User, "associations" do
  it { is_expected.to belong_to(:curator_sponsor).class_name "User" }
  it { is_expected.to belong_to(:place).inverse_of :users }
  it { is_expected.to belong_to(:search_place).inverse_of(:search_users).class_name "Place" }
  it { is_expected.to belong_to(:site).inverse_of :users }
  it { is_expected.to belong_to(:suspended_by_user).class_name "User" }
  it { is_expected.to have_many(:annotations).dependent :destroy }
  it { is_expected.to have_many(:atlases).inverse_of(:user).dependent :nullify }
  it { is_expected.to have_many(:comments).dependent :destroy }
  it { is_expected.to have_many(:created_guide_sections).class_name("GuideSection").with_foreign_key("creator_id").inverse_of(:creator).dependent :nullify }
  it { is_expected.to have_many :deleted_observations }
  it { is_expected.to have_many :deleted_photos }
  it { is_expected.to have_many :deleted_sounds }
  it { is_expected.to have_many(:editing_guides).through(:guide_users) }
  it { is_expected.to have_many(:flags_as_flaggable_user).inverse_of(:flaggable_user).class_name("Flag").with_foreign_key("flaggable_user_id").dependent :nullify }
  it { is_expected.to have_many(:flags_as_flagger).inverse_of(:user).class_name "Flag" }
  it { is_expected.to have_many :flow_tasks }
  it { is_expected.to have_many(:friendships).dependent :destroy }
  it { is_expected.to have_many(:friendships_as_friend).class_name("Friendship").with_foreign_key("friend_id").inverse_of(:friend).dependent :destroy }
  it { is_expected.to have_many(:guide_users).inverse_of(:user).dependent :delete_all }
  it { is_expected.to have_many(:guides).dependent(:destroy).inverse_of :user }
  it { is_expected.to have_many(:identifications).dependent :destroy }
  it { is_expected.to have_many(:journal_posts).class_name("Post").dependent :destroy }
  it { is_expected.to have_many(:listed_taxa).dependent :nullify }
  it { is_expected.to have_many(:lists).dependent :destroy }
  it { is_expected.to have_many(:messages).dependent :destroy }
  it { is_expected.to have_many(:moderator_actions).inverse_of :user }
  it { is_expected.to have_many(:moderator_notes).inverse_of :user }
  it { is_expected.to have_many(:moderator_notes_as_subject).class_name("ModeratorNote").with_foreign_key("subject_user_id").inverse_of(:subject_user).dependent :destroy }
  it { is_expected.to have_many(:observation_field_values).dependent(:nullify).inverse_of :user }
  it { is_expected.to have_many(:observation_fields).dependent(:nullify).inverse_of :user }
  it { is_expected.to have_many(:observations).dependent :destroy }
  it { is_expected.to have_many(:parentages).class_name("UserParent").with_foreign_key("parent_user_id").inverse_of :parent_user }
  it { is_expected.to have_many(:photos).dependent :destroy }
  it { is_expected.to have_many(:places).dependent :nullify }
  it { is_expected.to have_many :posts }
  it { is_expected.to have_many :projects }
  it { is_expected.to have_many(:project_observations).dependent :nullify }
  it { is_expected.to have_many(:project_user_invitations).dependent :nullify }
  it { is_expected.to have_many(:project_user_invitations_received).dependent(:delete_all).class_name "ProjectUserInvitation" }
  it { is_expected.to have_many(:project_users).dependent :destroy }
  it { is_expected.to have_many(:provider_authorizations).dependent :delete_all }
  it { is_expected.to have_many(:quality_metrics).dependent :destroy }
  it { is_expected.to have_many(:saved_locations).inverse_of(:user).dependent :destroy }
  it { is_expected.to have_many(:site_admins).inverse_of :user }
  it { is_expected.to have_many(:sounds).dependent :destroy }
  it { is_expected.to have_many(:sources).dependent :nullify }
  it { is_expected.to have_many(:subscriptions).dependent :delete_all }
  it { is_expected.to have_many(:taxa).with_foreign_key("creator_id").inverse_of :creator }
  it { is_expected.to have_many(:taxon_changes).inverse_of :user }
  it { is_expected.to have_many(:taxon_curators).inverse_of(:user).dependent :destroy }
  it { is_expected.to have_many :taxon_framework_relationships }
  it { is_expected.to have_many(:taxon_links).dependent :nullify }
  it { is_expected.to have_many(:taxon_names).with_foreign_key("creator_id").inverse_of :creator }
  it { is_expected.to have_many(:updated_guide_sections).class_name("GuideSection").with_foreign_key("updater_id").inverse_of(:updater).dependent :nullify }
  it { is_expected.to have_many(:updated_observation_field_values).dependent(:nullify).inverse_of(:updater).with_foreign_key("updater_id").class_name "ObservationFieldValue" }
  it { is_expected.to have_many(:user_blocks).inverse_of(:user).dependent :destroy }
  it { is_expected.to have_many(:user_blocks_as_blocked_user).class_name("UserBlock").with_foreign_key("blocked_user_id").inverse_of(:blocked_user).dependent :destroy }
  it { is_expected.to have_many(:user_mutes).inverse_of(:user).dependent :destroy }
  it { is_expected.to have_many(:user_mutes_as_muted_user).class_name("UserMute").with_foreign_key("muted_user_id").inverse_of(:muted_user).dependent :destroy }
  it { is_expected.to have_many(:user_privileges).inverse_of(:user).dependent :delete_all }
  it { is_expected.to have_one(:flickr_identity).dependent :delete }
  it { is_expected.to have_one(:soundcloud_identity).dependent :delete }
  it { is_expected.to have_one(:user_parent).dependent(:destroy).inverse_of :user }
end

describe User, "validations" do
  it { is_expected.to validate_exclusion_of(:login).in_array %w(password new edit create update delete destroy) }
  it { is_expected.to validate_exclusion_of(:password).in_array %w(password) }
  it { is_expected.to validate_length_of(:login).is_at_least(User::MIN_LOGIN_SIZE).is_at_most User::MAX_LOGIN_SIZE }
  it { is_expected.to validate_length_of(:name).is_at_most(100).allow_blank }
  it { is_expected.to validate_length_of(:time_zone).is_at_least(3).allow_nil }
  it { is_expected.to validate_presence_of :login }
  it { is_expected.to validate_presence_of :password }
  it { is_expected.to validate_presence_of :email }
  it { is_expected.to validate_uniqueness_of(:login).case_insensitive }
end

describe User do
  before(:all) do
    DatabaseCleaner.clean_with(:truncation, except: %w[spatial_ref_sys])
  end

  describe "creation" do
    it "increments User#count" do
      expect { create( :user ) }.to change( User, :count ).by( 1 )
    end

    it "initializes confirmation_token" do
      expect( create( :user, :as_unconfirmed ).confirmation_token ).not_to be_blank
    end

    it "should require email under normal circumstances" do
      u = build :user
      u.email = nil
      expect( u ).not_to be_valid
    end

    it "should set the URI" do
      u = User.make!
      expect(u.uri).to eq(UrlHelper.user_url(u))
    end

    it "should set a default locale" do
      u = User.make!
      expect(u.locale).to eq I18n.locale.to_s
    end

    it "should strip the login" do
      u = User.make(:login => "foo ")
      u.save
      expect(u.login).to eq "foo"
      expect(u).to be_valid
    end

    it "should strip the email" do
      u = User.make(:email => "foo@bar.com ")
      u.save
      expect(u.email).to eq "foo@bar.com"
      expect(u).to be_valid
    end

    it "should not allow time_zone to be a blank string" do
      expect( User.make!( time_zone: "" ).time_zone ).to be_nil
    end
    
    it "should set latitude and longitude" do
      stub_request(:get, /#{INatAPIService::ENDPOINT}/).
        to_return(status: 200, body: '{
          "results": {
            "country": "US",
            "city": "Fairhaven",
            "ll": [
              41.6318,
              -70.8801
            ]
          }
        }', headers: { "Content-Type" => "application/json" })
      u = User.make(:last_ip => "128.128.128.128")
      u.save
      expect(u.latitude).to eq 41.6318
      expect(u.longitude).to eq -70.8801
      expect(u.lat_lon_acc_admin_level).to eq Place::COUNTY_LEVEL
    end

    it "should validate email address domains" do
      CONFIG.banned_emails = [ "testban.com" ]
      expect {
        User.make!(email: "someone@testban.com")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    describe "email domain exists validation" do
      before(:all) { enable_user_email_domain_exists_validation }
      after(:all) { disable_user_email_domain_exists_validation }

      it "should allow email domains that exist" do
        [
          "gmail.com",
          "yahoo.com",
          "hotmail.com",
          "aol.com",
          "mail.usf.edu",
          "icloud.com",
          "questagame.com",
          "outlook.com",
          "comcast.net",
          "me.com",
          "live.com",
          "sbcglobal.net",
          "msn.com",
          "mac.com",
          "att.net",
          "cvcaroyals.org",
          "ymail.com"
        ].each do |domain|
          u = User.make!( email: "someone@#{domain}" )
          expect( u ).to be_valid
        end
      end

      it "should disallow email domains that do not exist" do
        expect {
          User.make!( email: "someone@sdjgfslkjfgsjfkg.com" )
        }.to raise_error( ActiveRecord::RecordInvalid )
      end
    end

    it "should strip html out of the name" do
      name = "Trillian"
      u = User.make!( name: "#{name}<script>foo</script>" )
      expect( u.name ).to eq name
    end

    it "should strip an email out of the name" do
      email = "foo@bar.com"
      u = User.make!( name: email )
      expect( u.name ).not_to include email
      u = User.make!( name: "this is my email: #{email}" )
      expect( u.name ).not_to include email
      u = User.make!( name: "#{email} is my email" )
      expect( u.name ).not_to include email
    end

    it "should allow @ sign in name if it doesn't look like an email" do
      expect( User.make!( name: "@username" ) ).to be_valid
    end
  end

  describe "update" do
    elastic_models( Observation )

    it "should strip html out of the name" do
      u = User.make!
      n = u.name
      u.update( name: "#{u.name}<script>foo</script>" )
      expect( u.name ).to eq n
    end
    
    it "should update the site_id on the user's observations" do
      s1 = Site.make!
      s2 = Site.make!
      u = User.make!(site: s1)
      o = Observation.make!(user: u, site: s1)
      without_delay { u.update(site: s2) }
      o.reload
      expect( o.site ).to eq s2
    end

    it "should update the site_id in the elastic index" do
      s1 = Site.make!
      s2 = Site.make!
      u = User.make!(site: s1)
      o = Observation.make!(user: u, site: s1)
      without_delay { u.update(site: s2) }
      o.reload
      es_o = Observation.elastic_paginate(where: {site_id: s2.id}).first
      expect( es_o ).to eq o
    end

    it "should not update the native_realname on all photos if the name changed" do
      u = User.make!( name: "timdal the great" )
      o = make_research_grade_observation( user: u )
      p = o.photos.first
      expect( p.native_realname ).to be_blank
      new_name = "Zolophon the Destroyer"
      without_delay { u.update( name: new_name ) }
      p.reload
      expect( p.native_realname ).to be_blank
    end

    it "should not update the native_username on all photos if the login changed" do
      o = make_research_grade_observation
      u = o.user
      p = o.photos.first
      expect( p.native_username ).to be_blank
      new_login = "zolophon"
      without_delay { u.update( login: new_login ) }
      p.reload
      expect( p.native_username ).to be_blank
    end

    it "should not update photos by other users when the name changes" do
      target_o = make_research_grade_observation
      target_u = target_o.user
      other_o = make_research_grade_observation
      other_p = other_o.photos.first
      other_u = other_o.user
      expect( other_p.native_realname ).to be_blank
      new_login = "zolophon"
      without_delay { target_u.update( login: new_login ) }
      other_p.reload
      expect( other_p.native_realname ).to be_blank
    end

    describe 'disallows illegitimate logins' do
      bad_logins.each do |login_str|
        it "'#{login_str}'" do
          u = User.make!
          u.login = login_str
          expect(u).not_to be_valid
        end
      end
    end

  end

  #
  # Validations
  #

  it "should not allow duplicate emails" do
    existing = User.make!
    u = User.make(:email => existing.email)
    expect(u).to_not be_valid
    expect(u.errors['email']).to_not be_blank
  end

  describe 'allows legitimate logins:' do
    ['whatisthewhat', 'zoooooolander', 'hello-_therefunnycharcom'].each do |login_str|
      it "'#{login_str}'" do
        expect {
          u = create_user(:login => login_str)
          expect(u.errors[:login]).to be_blank
        }.to change(User, :count).by(1)
      end
    end
  end
  describe 'disallows illegitimate logins:' do
    bad_logins.each do |login_str|
      it login_str do
        expect( User.make(login: login_str) ).not_to be_valid
      end
    end
  end

  it 'requires password confirmation' do
    expect {
      u = create_user(:password_confirmation => "")
      expect(u.errors[:password_confirmation]).to_not be_blank
    }.to_not change(User, :count)
  end

  describe 'allows legitimate emails:' do
    ['foo@bar.com', 'foo@newskool-tld.museum', 'foo@twoletter-tld.de', 'foo@nonexistant-tld.qq',
     'r@a.wk', '1234567890-234567890-234567890-234567890-234567890-234567890-234567890-234567890-234567890@gmail.com',
     'hello.-_there@funnychar.com', 'uucp%addr@gmail.com', 'hello+routing-str@gmail.com',
     'domain@can.haz.many.sub.doma.in', 'student.name@university.edu', 'foo@ostal.cat'
    ].each do |email_str|
      it "'#{email_str}'" do
        expect {
          u = create_user(:email => email_str)
          expect(u.errors[:email]).to     be_blank
        }.to change(User, :count).by(1)
      end
    end
  end

  describe 'allows legitimate names:' do
    ['Andre The Giant (7\'4", 520 lb.) -- has a posse',
     '', '1234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890',
    ].each do |name_str|
      it "'#{name_str}'" do
        expect {
          u = create_user(:name => name_str)
          expect(u.errors[:name]).to     be_blank
        }.to change(User, :count).by(1)
      end
    end
  end
  describe "disallows illegitimate names" do
    [
     '1234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_'
     ].each do |name_str|
      it "'#{name_str}'" do
        expect {
          u = create_user(:name => name_str)
          expect(u.errors[:name]).not_to be_blank
        }.not_to change(User, :count)
      end
    end
  end

  it 'resets password' do
    user = User.make!
    user.update(:password => 'new password', :password_confirmation => 'new password')
    expect(User.authenticate(user.login, 'new password')).to eq user
  end

  it 'does not rehash password' do
    pw = "fooosdgsg"
    user = User.make!(:password => pw, :password_confirmation => pw)
    user.update(:login => 'quentin2')
    expect(User.authenticate('quentin2', pw)).to eq user
  end

  describe "authentication" do
    before(:each) do
      @pw = "fooosdgsg"
      @user = User.make!(:password => @pw, :password_confirmation => @pw)
    end

    it 'authenticates user' do
      expect(User.authenticate(@user.login, @pw)).to eq @user
    end

    it "doesn't authenticate user with bad password" do
      expect(User.authenticate(@user.login, 'invalid_password')).to be_blank
    end

    it 'does not authenticate suspended user' do
      @user.suspend!
      expect(User.authenticate(@user.login, @pw)).not_to eq @user
    end
  end

  describe "remembering" do
    before(:each) do
      @user = User.make!
    end

    it 'sets remember token' do
      @user.remember_me!
      expect(@user.remember_token).not_to be_blank
      expect(@user.remember_expires_at).not_to be_blank
    end

    it 'unsets remember token' do
      @user.remember_me!
      expect(@user.remember_token).not_to be_blank
      @user.forget_me!
      expect(@user.remember_token).to be_blank
    end

    it 'remembers me default two weeks' do
      Time.use_zone(@user.time_zone) do
        before = 13.days.from_now.utc
        @user.remember_me!
        after = 15.days.from_now.utc
        expect(@user.remember_token).not_to be_blank
        expect(@user.remember_expires_at).not_to be_blank
        expect(@user.remember_expires_at.between?(before, after)).to be true
      end
    end
  end

  it 'suspends user' do
    user = User.make!
    user.suspend!
    expect(user).to be_suspended
  end
  
  describe "deletion" do
    elastic_models( Observation )
    
    before do
      @user = User.make!
    end

    it "should create a deleted user" do
      @user.destroy
      deleted_user = DeletedUser.last
      expect(deleted_user).not_to be_blank
      expect(deleted_user.user_id).to eq @user.id
      expect(deleted_user.login).to eq @user.login
      expect(deleted_user.email).to eq @user.email
    end

    it "should not update photos by other users" do
      target_o = make_research_grade_observation
      target_u = target_o.user
      other_o = make_research_grade_observation
      other_p = other_o.photos.first
      other_u = other_o.user
      expect( other_p.native_realname ).to be_blank
      new_login = "zolophon"
      without_delay { target_u.destroy }
      other_p.reload
      expect( other_p.native_realname ).to be_blank
    end

    it "should remove oauth access tokens" do
      token = Doorkeeper::AccessToken.create!( resource_owner_id: @user.id, application: OauthApplication.make! )
      expect( token ).to be_persisted
      @user.destroy
      expect( Doorkeeper::AccessToken.where( id: token.id ).first ).to be_blank
    end

    it "should remove blocks this user has made" do
      user_block = UserBlock.make!( user: @user )
      @user.destroy
      expect( UserBlock.where( user_id: user_block.id ).first ).to be_blank
    end
    it "should remove blocks against this user" do
      user_block = UserBlock.make!( blocked_user: @user )
      @user.destroy
      expect( UserBlock.where( blocked_user_id: user_block.id ).first ).to be_blank
    end

    it "should delete associated project rules" do
      user = User.make!
      collection = Project.make!(project_type: "collection")
      rule = collection.project_observation_rules.build( operator: "observed_by_user?", operand: user )
      rule.save!
      expect( Project.find( collection.id ).project_observation_rules.length ).to eq 1
      user.destroy
      expect( Project.find( collection.id ).project_observation_rules.length ).to eq 0
    end

    it "should reindex observations faved by the user" do
      o = Observation.make!
      u = User.make!
      o.vote_by voter: u, vote: true
      es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
      expect( es_response.votes.size ).to eq 1
      u.destroy
      Delayed::Worker.new.work_off
      Delayed::Worker.new.work_off
      es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
      expect( es_response.votes.size ).to eq 0
    end

    it "should destroy friendships where user is the friend" do
      f = Friendship.make!
      f.friend.destroy
      expect( Friendship.find_by_id( f.id ) ).to be_blank
    end
  end

  describe "sane_destroy" do

    elastic_models( Observation )
    
    let(:user) { make_user_with_privilege( UserPrivilege::ORGANIZER ) }

    it "should destroy the user" do
      user.sane_destroy
      expect( User.find_by_id( user.id ) ).to be_blank
    end

    it "should not queue jobs to refresh the users lists" do
      Delayed::Job.delete_all
      user.sane_destroy
      jobs = Delayed::Job.all
      # jobs.map(&:handler).each{|h| puts h}
      expect(jobs.select{ |j| j.handler =~ /'List'.*\:refresh/m }).to be_blank
    end

    it "should not queue refresh_with_observation jobs" do
      Delayed::Job.delete_all
      user.sane_destroy
      expect(Delayed::Job.all.select{ |j| j.handler =~ /refresh_with_observation/m }).to be_blank
    end

    describe "for user with observations in places" do
      let(:place) { make_place_with_geom }
      it "should queue jobs to refresh check lists" do
        o = without_delay do
          Observation.make!(
            user: user,
            taxon: Taxon.make!,
            latitude: place.latitude,
            longitude: place.longitude
          )
        end

        # stubbing GET
        response_json = <<-JSON
        {
          "count_without_taxon": 0,
          "size": 1,
          "results": [
            {
              "id": #{o.taxon_id},
              "name": "Animalia",
              "rank": "kingdom",
              "rank_level": 70,
              "is_active": true,
              "parent_id": 48460,
              "descendant_obs_count": 6,
              "direct_obs_count": 0
            }
          ]
        }
        JSON
        stub_request(:get, /#{INatAPIService::ENDPOINT}/).
          to_return(status: 200, body: response_json,
            headers: {"Content-Type" => "application/json"})

        user.sane_destroy
        jobs = Delayed::Job.all
        # jobs.map(&:handler).each{|h| puts h}
        expect(jobs.select{|j| j.handler =~ /'CheckList'.*\:refresh/m}).not_to be_blank
      end

      it "should refresh check lists" do
        t = Taxon.make!(rank: "species")
        o = without_delay do
          make_research_grade_observation(
            taxon: t,
            user: user,
            latitude: place.latitude,
            longitude: place.longitude
          )
        end

        # stubbing GET
        response_json = <<-JSON
        {
          "count_without_taxon": 0,
          "size": 1,
          "results": [
            {
              "id": #{o.taxon_id},
              "name": "Animalia",
              "rank": "kingdom",
              "rank_level": 70,
              "is_active": true,
              "parent_id": 48460,
              "descendant_obs_count": 6,
              "direct_obs_count": 0
            }
          ]
        }
        JSON
        stub_request(:get, /#{INatAPIService::ENDPOINT}/).
          to_return(status: 200, body: response_json,
            headers: {"Content-Type" => "application/json"})
        
        expect( place.check_list.listed_taxa.find_by_taxon_id( t.id ) ).not_to be_blank
        user.sane_destroy
        Delayed::Worker.new.work_off
        Delayed::Worker.new.work_off
        expect( Observation.find_by_id( o.id ) ).to be_blank
        expect( place.check_list.listed_taxa.find_by_taxon_id( t.id ) ).to be_blank
      end

      it "should remove remove taxa from check lists that were only confirmed by the user's observations" do
        o = without_delay do
          make_research_grade_observation(
            user: user,
            latitude: place.latitude,
            longitude: place.longitude
          )
        end
        t = o.taxon
        expect( ListedTaxon.where( place_id: place, taxon_id: t ) ).not_to be_blank
        user.sane_destroy
        Delayed::Worker.new.work_off
        Delayed::Worker.new.work_off
        expect(ListedTaxon.where( place_id: @place, taxon_id: t ) ).to be_blank
      end
    end

    describe "for owner of a project" do
      let(:project) { without_delay { Project.make!( user: user ) } }

      it "should not queue jobs to refresh project lists" do
        expect( project.project_list ).not_to be_blank
        Delayed::Job.delete_all
        user.sane_destroy
        jobs = Delayed::Job.all
        # jobs.map(&:handler).each{|h| puts h}
        expect(jobs.select{|j| j.handler =~ /'ProjectList'.*\:refresh/m}).to be_blank
      end

      it "should assign projects to a manager" do
        po = make_project_observation( project: project )
        m = ProjectUser.make!( role: ProjectUser::MANAGER, project: project )
        user.sane_destroy
        project.reload
        expect( project.user_id ).to eq( m.user_id )
      end

      describe "notifications" do
        before do
          enable_has_subscribers
        end
        after do
          disable_has_subscribers
        end
        it "should generate for new project owners" do
          p = Project.make!( user: user )
          po = make_project_observation( project: p )
          m = without_delay do
            ProjectUser.make!( role: ProjectUser::MANAGER, project: p )
          end
          expect( UpdateAction.unviewed_by_user_from_query( m.user_id, { } ) ).to eq false
          without_delay { user.sane_destroy }
          expect( UpdateAction.unviewed_by_user_from_query( m.user_id, resource: p ) ).to eq true
        end

        it "should generate for new project owners even if they're new members" do
          p = Project.make!( user: user )
          make_project_observation( project: p )
          pu = create( :project_user, project: p, role: ProjectUser::MANAGER )
          expect( UpdateAction.unviewed_by_user_from_query( pu.user_id, {} ) ).to eq false
          without_delay { user.sane_destroy }
          expect( Project.find_by_id( p.id ) ).not_to be_blank
          expect( UpdateAction.unviewed_by_user_from_query( pu.user_id, resource: p ) ).to eq true
        end
      end
    end

    describe "user with identifications" do
      it "should reassess the community taxon of observations the user has identified" do
        o = make_research_grade_candidate_observation( taxon: Taxon.make!( rank: Taxon::SPECIES ) )
        expect( o.community_taxon ).to be_blank
        i = Identification.make!( observation: o, taxon: o.taxon, user: user )
        o.reload
        expect( o.community_taxon ).to eq i.taxon
        user.sane_destroy
        o.reload
        expect( o.community_taxon ).to be_blank
      end

      it "should reassess the quality grade of observations the user has identified" do
        o = make_research_grade_candidate_observation( taxon: Taxon.make!( rank: Taxon::SPECIES ) )
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
        i = Identification.make!( observation: o, taxon: o.taxon, user: user )
        o.reload
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
        without_delay { user.sane_destroy }
        o.reload
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end
    end

    it "should not delete taxa the user created" do
      t = Taxon.make!( creator: user )
      Delayed::Job.delete_all
      user.sane_destroy
      expect( Taxon.find_by_id( t.id ) ).not_to be_blank
    end
    it "should not delete taxon names the user created" do
      tn = TaxonName.make!( creator: user )
      Delayed::Job.delete_all
      user.sane_destroy
      expect( TaxonName.find_by_id( tn.id ) ).not_to be_blank
    end
    it "should delete observed_by_user? project observation rules" do
      por = ProjectObservationRule.make!( operator: "observed_by_user?", operand: user )
      user.reload
      user.sane_destroy
      expect( ProjectObservationRule.find_by_id( por.id ) ).to be_blank
    end
    it "should delete not_observed_by_user? project observation rules" do
      por = ProjectObservationRule.make!( operator: "not_observed_by_user?", operand: user )
      user.reload
      user.sane_destroy
      expect( ProjectObservationRule.find_by_id( por.id ) ).to be_blank
    end
    it "should reindex a project with a observed_by_user? rule" do
      por = ProjectObservationRule.make!( operator: "observed_by_user?", operand: user )
      project = por.ruler
      es_project = Project.elastic_search( where: { id: project.id } ).results.results[0]
      es_por = es_project.project_observation_rules.detect do | r |
        r.operator == "observed_by_user?" && r.operand_id == user.id
      end
      expect( es_por ).not_to be_blank
      user.sane_destroy
      project.reload
      es_project = Project.elastic_search( where: { id: project.id } ).results.results[0]
      es_por = es_project.project_observation_rules.detect do | r |
        r.operator == "observed_by_user?" && r.operand_id == user.id
      end
      expect( es_por ).to be_blank
    end
  end

  describe "suspension" do
    it "deletes unread sent messages" do
      fu = UserPrivilege.make!.user # User.make!
      tu = UserPrivilege.make!.user # User.make!
      m = make_message(:user => fu, :from_user => fu, :to_user => tu)
      m.send_message
      expect(m.to_user_copy).not_to be_blank
      fu.suspend!
      m.reload
      expect(m.to_user_copy).to be_blank
    end

    it "should not delete the suspended user's messages" do
      fu = UserPrivilege.make!.user # User.make!
      tu = UserPrivilege.make!.user # User.make!
      m = make_message(:user => fu, :from_user => fu, :to_user => tu)
      m.send_message
      expect(m.to_user_copy).not_to be_blank
      fu.suspend!
      expect(Message.find_by_id(m.id)).not_to be_blank
    end
  end

  describe "being unsuspended" do

    before do
      @user = User.make!
      @user.suspend!
    end

    it 'reverts to active state' do
      @user.unsuspend!
      expect(@user).to be_active
    end
  end
  
  describe "licenses" do
    elastic_models( Observation )

    it "should update existing observations if requested" do
      u = User.make!
      o = Observation.make!(:user => u)
      u.preferred_observation_license = Observation::CC_BY
      u.update(:make_observation_licenses_same => true)
      o.reload
      expect(o.license).to eq Observation::CC_BY
    end
    
    it "should update existing photo if requested" do
      u = User.make!
      p = LocalPhoto.make!(:user => u)
      u.preferred_photo_license = Observation::CC_BY
      u.update(:make_photo_licenses_same => true)
      p.reload
      expect(p.license).to eq Photo.license_number_for_code(Observation::CC_BY)
    end

    it "should not update GoogleStreetViewPhotos" do
      u = User.make!
      p = GoogleStreetViewPhoto.make!(:user => u)
      u.preferred_photo_license = Observation::CC_BY
      u.update(:make_photo_licenses_same => true)
      p.reload
      expect(p.license).to eq Photo::COPYRIGHT
    end
  end

  describe "merge" do
    elastic_models( Observation, Identification )
    
    let(:keeper) { User.make! }
    let(:reject) { User.make! }

    it "should move observations" do
      o = Observation.make!(:user => reject)
      without_delay do
        keeper.merge(reject)
      end
      o.reload
      expect(o.user_id).to eq keeper.id
    end

    it "should update the observations_count" do
      Observation.make!( user: keeper )
      Observation.make!( user: reject )
      Delayed::Worker.new.work_off
      keeper.reload
      expect( keeper.observations_count ).to eq 1
      keeper.merge( reject )
      Delayed::Worker.new.work_off
      keeper.reload
      expect( keeper.observations.count ).to eq 2
      expect( keeper.observations_count ).to eq 2
    end

    it "should update the identifications_count" do
      Identification.make!( user: reject )
      Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
      reject.reload
      expect( reject.identifications_count ).to eq 1
      expect( keeper.identifications_count ).to eq 0
      keeper.merge( reject )
      Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
      keeper.reload
      expect( keeper.identifications_count ).to eq 1
    end
    it "should reindex observations by the user" do
      o = Observation.make!( user: reject )
      Delayed::Worker.new.work_off
      expect(
        Observation.elastic_search( filters: [ { term: { id: o.id } } ] ).response.hits.hits[0]._source.user.id
      ).to eq reject.id
      keeper.merge( reject )
      Delayed::Worker.new.work_off
      keeper.reload
      expect(
        Observation.elastic_search( filters: [ { term: { id: o.id } } ] ).response.hits.hits[0]._source.user.id
      ).to eq keeper.id
    end
    it "should reindex observations identified by the user" do
      o = Identification.make!( user: reject ).observation
      Delayed::Worker.new.work_off
      expect(
        Observation.elastic_search( filters: [ { term: { id: o.id } } ] ).response.hits.hits[0]._source.identifier_user_ids
      ).to include reject.id
      keeper.merge( reject )
      Delayed::Worker.new.work_off
      keeper.reload
      expect(
        Observation.elastic_search( filters: [ { term: { id: o.id } } ] ).response.hits.hits[0]._source.identifier_user_ids
      ).to include keeper.id
    end
    it "should reindex the user" do
      o = Observation.make!( user: reject )
      Delayed::Worker.new.work_off
      expect(
        User.elastic_search( filters: [ { term: { id: keeper.id } } ] ).response.hits.hits[0]._source.observations_count
      ).to eq 0
      keeper.merge( reject )
      Delayed::Worker.new.work_off
      expect(
        User.elastic_search( filters: [ { term: { id: keeper.id } } ] ).response.hits.hits[0]._source.observations_count
      ).to eq Observation.by( keeper ).count
    end

    it "should remove self friendships" do
      f = Friendship.make!(:user => reject, :friend => keeper)
      keeper.merge(reject)
      expect(Friendship.find_by_id(f.id)).to be_blank
      expect(keeper.friendships.map(&:friend_id)).not_to include(keeper.id)
    end

    it "should remove duplicate friendships" do
      friend = User.make!
      f_reject = Friendship.make!( user: reject, friend: friend )
      f_keeper = Friendship.make!( user: keeper, friend: friend )
      keeper.merge( reject )
      expect( Friendship.find_by_id( f_reject.id ) ).to be_blank
      expect( Friendship.find_by_id( f_keeper.id ) ).not_to be_blank
    end

    it "should queue a job to do the slow stuff" do
      Delayed::Job.delete_all
      stamp = Time.now
      keeper.merge(reject)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      # puts jobs.map(&:handler).inspect
      expect(jobs.select{|j| j.handler =~ /User.*\:merge_cleanup/m}).not_to be_blank
    end

    it "should not result in duplicate project users" do
      project = Project.make!
      keeper_pu = ProjectUser.make!( project: project, user: keeper )
      reject_pu = ProjectUser.make!( project: project, user: reject )
      expect( keeper.project_users.count ).to eq 1
      keeper.merge( reject )
      keeper.reload
      expect( keeper.project_users.count ).to eq 1
    end

    describe "matching identifications on the same observation" do
      let(:observation) { Observation.make! }
      let(:keeper_ident) { Identification.make!( observation: observation, user: keeper ) }
      let(:reject_ident) { Identification.make!( observation: observation, user: reject, taxon: keeper_ident.taxon ) }
      it "should withdraw the reject's identification" do
        expect( reject_ident.user_id ).not_to eq keeper_ident.user_id
        keeper.merge( reject )
        Delayed::Worker.new.work_off
        reject_ident.reload
        expect( reject_ident ).not_to be_current
      end
      it "should not destroy the reject's other identifications" do
        expect( reject_ident.user_id ).not_to eq keeper_ident.user_id
        other_ident = Identification.make!( user: reject )
        keeper.merge( reject )
        Delayed::Worker.new.work_off
        expect( Identification.find_by_id( other_ident.id ) ).not_to be_blank
      end
    end

    it "should update flaggable_user_id" do
      o = Observation.make!( user: reject )
      f = Flag.make!( flaggable: o )
      expect( f.flaggable_user_id ).to eq reject.id
      keeper.merge( reject )
      Delayed::Worker.new.work_off
      f.reload
      expect( f.flaggable_user_id ).to eq keeper.id
    end
  end

  describe "suggest_login" do
    it "should suggest logins that are too short" do
      suggestion = User.suggest_login("AJ")
      expect(suggestion).not_to be_blank
      expect(suggestion.size).to be >= User::MIN_LOGIN_SIZE
    end

    it "should not suggests logins that are too big" do
      suggestion = User.suggest_login("Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor")
      expect(suggestion).not_to be_blank
      expect(suggestion.size).to be <= User::MAX_LOGIN_SIZE
    end
    
    it "should not suggest logins that begin with a number" do
      suggestion = User.suggest_login("2bornot2b")
      expect(suggestion).not_to be_blank
      expect(suggestion).not_to start_with '2'
    end

    it "should not suggest purely integer logins" do
      suggestion = User.suggest_login("")
      expect(suggestion).not_to be_blank
      expect(suggestion).to eq "naturalist"

      suggestion = User.suggest_login("育")
      expect(suggestion).not_to be_blank
      expect(suggestion).to eq "naturalist"
    end

    it "should suggest naturalistX for more empty suggestions" do
      User.make!(login: "naturalist")
      suggestion = User.suggest_login("")
      expect(suggestion).not_to be_blank
      expect(suggestion).to eq "naturalist1"

      User.make!(login: "naturalist1")
      suggestion = User.suggest_login("")
      expect(suggestion).not_to be_blank
      expect(suggestion).to eq "naturalist2"
    end

  end

  describe "community taxa preference" do
    elastic_models( Identification )

    it "should not remove community taxa when set to false" do
      o = Observation.make!
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).to eq i1.taxon
      o.user.update(:prefers_community_taxa => false)
      Delayed::Worker.new.work_off
      o.reload
      expect(o.taxon).to be_blank
    end

    it "should set observation taxa to owner's ident when set to false" do
      owners_taxon = Taxon.make!
      o = Observation.make!(:taxon => owners_taxon)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      i3 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to eq o.community_taxon
      o.user.update(:prefers_community_taxa => false)
      Delayed::Worker.new.work_off
      o.reload
      expect(o.taxon).to eq owners_taxon
    end

    it "should not set observation taxa to owner's ident when set to false for observations that prefer community taxon" do
      owners_taxon = Taxon.make!
      o = Observation.make!(:taxon => owners_taxon, :prefers_community_taxon => true)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      i3 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to eq o.community_taxon
      o.user.update(:prefers_community_taxa => false)
      Delayed::Worker.new.work_off
      o.reload
      expect(o.taxon).to eq o.community_taxon
    end

    it "should change observation taxa to community taxa when set to true" do
      o = Observation.make!
      o.user.update(:prefers_community_taxa => false)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to be_blank
      o.user.update(:prefers_community_taxa => true)
      Delayed::Worker.new.work_off
      o.reload
      expect(o.taxon).to eq o.community_taxon
    end

    it "should re-assess quality grade when changed" do
      u = User.make!( prefers_community_taxa: false )
      owners_taxon = Taxon.make!( rank: Taxon::SPECIES )
      community_taxon = Taxon.make!( rank: Taxon::SPECIES )
      o = make_research_grade_candidate_observation( user: u, taxon: owners_taxon )
      3.times { Identification.make!( observation: o, taxon: community_taxon ) }
      o.reload
      expect( o.owners_identification ).to be_maverick
      expect( o.quality_grade ).to eq Observation::CASUAL
      o.user.update( prefers_community_taxa: true )
      Delayed::Worker.new.work_off
      o.reload
      expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
    end

    it "should not create new identifications for the observer when set to true" do
      user = User.make!( prefers_community_taxa: false )
      family = Taxon.make!( rank: Taxon::FAMILY )
      genus = Taxon.make!( rank: Taxon::GENUS, parent: family )
      species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
      o = Observation.make!( user: user )
      owners_ident = Identification.make!( user: user, observation: o, taxon: family )
      2.times do
        Identification.make!( observation: o, taxon: species )
      end
      o.reload
      expect( o.taxon ).to eq owners_ident.taxon
      expect( o.community_taxon ).to eq species
      expect( o.identifications.by( user ).count ).to eq 1
      user.update( prefers_community_taxa: true )
      Delayed::Worker.new.work_off
      o.reload
      expect( o.identifications.by( user ).count ).to eq 1
      owners_ident.reload
      expect( owners_ident ).to be_current
    end
  end

  describe "active_ids" do
    it "should calculate active users across several classes" do
      expect(User.active_ids.length).to eq 0
      expect(Identification.count).to eq 0
      observation = Observation.make!
      # observations are made with identifications, so we'll start fresh
      Identification.delete_all
      Identification.make!(observation: observation)
      expect(Identification.count).to eq 1
      Comment.make!(parent: observation)
      Post.make!(parent: observation)
      expect(User.active_ids.length).to eq 4
    end

    it "should count the same user only once" do
      expect(User.active_ids.length).to eq 0
      user = User.make!
      observation = Observation.make!(user: user)
      Identification.delete_all
      Identification.make!(observation: observation, user: user)
      Comment.make!(parent: observation, user: user)
      Post.make!(parent: observation, user: user)
      expect(User.active_ids.length).to eq 1
    end
  end

  describe "mentions" do
    elastic_models( Observation )
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "can prefer to not get mentions" do
      u = User.make!
      expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
      c1 = without_delay { Comment.make!(body: "hey @#{ u.login }") }
      c2 = without_delay { Comment.make!(body: "hey @#{ u.login }") }
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: c1) ).to eq true
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: c2) ).to eq true

      u.update(prefers_receive_mentions: false)
      c3 = without_delay { Comment.make!(body: "hey @#{ u.login }") }
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: c3) ).to eq false
    end

    it "can prefer to not get mentions in emails" do
      u = User.make!
      expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
      c = without_delay { Comment.make!(body: "hey @#{ u.login }") }
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: c) ).to eq true
      deliveries = ActionMailer::Base.deliveries.size
      u.update(prefers_mention_email_notification: false)
      UpdateAction.email_updates_to_user(u, 1.hour.ago, Time.now)
      expect( ActionMailer::Base.deliveries.size ).to eq deliveries
      u.update(prefers_mention_email_notification: true)
      UpdateAction.email_updates_to_user(u, 1.hour.ago, Time.now)
      expect( ActionMailer::Base.deliveries.size ).to eq (deliveries + 1)
    end
  end

  describe "prefers_redundant_identification_notifications" do
    elastic_models( Observation )
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    let(:u) { User.make! }
    let(:genus) { Taxon.make!(rank: Taxon::GENUS) }
    let(:species) { Taxon.make!(rank: Taxon::SPECIES, parent: genus) }
    let(:subspecies) { Taxon.make!(rank: Taxon::SUBSPECIES, parent: species) }
    let(:o) { Observation.make!(taxon: species) }
    let(:i) { Identification.make!(observation: o, user: u, taxon: species)}

    describe "true" do
      before do
        u.update(prefers_redundant_identification_notifications: true)
        expect( i ).to be_persisted
        expect( u.subscriptions.map(&:resource) ).to include o
      end
      it "should allow identifications that match with the subscriber" do
        id = without_delay { Identification.make!(observation: o, taxon: species) }
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: id) ).to eq true
      end
      it "should allow identifications of taxa that are descendants of the subscriber's taxon" do
        id = without_delay { Identification.make!(observation: o, taxon: subspecies) }
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: id) ).to eq true
      end
      it "should allow identifications of taxa that are ancestors of the subscriber's taxon" do
        id = without_delay { Identification.make!(observation: o, taxon: genus) }
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: id) ).to eq true
      end
    end

    describe "false" do
      before do
        u.update(prefers_redundant_identification_notifications: false)
        expect( i ).to be_persisted
        expect( u.subscriptions.map(&:resource) ).to include o
      end
      it "should suppress identifications that match with the subscriber" do
        id = without_delay { Identification.make!(observation: o, taxon: species) }
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: id) ).to eq false
      end
      it "should allow identifications of taxa that are descendants of the subscriber's taxon" do
        id = without_delay { Identification.make!(observation: o, taxon: subspecies) }
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: id) ).to eq true
      end
      it "should allow identifications of taxa that are ancestors of the subscriber's taxon" do
        id = without_delay { Identification.make!(observation: o, taxon: genus) }
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: id) ).to eq true
      end
      it "should allow notification if subscriber has no identification" do
        obs = Observation.make!(user: u)
        expect( obs.owners_identification ).to be_blank
        id = without_delay { Identification.make!(observation: obs) }
        expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: id) ).to eq true
      end
    end
  end

  describe "when flagged as spam" do
    elastic_models( Observation, Identification, Project )

    let(:user) { make_user_with_privilege( UserPrivilege::ORGANIZER ) }
    let(:flagger) { User.make! }

    it "should reindex observations as spam" do
      o = Observation.make!( user: user )
      Delayed::Worker.new.work_off
      es_o = Observation.elastic_search( where: { id: o.id } ).results[0]
      expect( es_o.spam ).to be false
      user.add_flag( flag: Flag::SPAM, user_id: flagger.id )
      Delayed::Worker.new.work_off
      o.reload
      expect( o.as_indexed_json[:spam] ).to be true
      es_o = Observation.elastic_search( where: { id: o.id } ).results[0]
      expect( es_o.spam ).to be true
    end
    it "should reindex identifications as spam" do
      i = Identification.make!( user: user )
      Delayed::Worker.new.work_off
      es_i = Identification.elastic_search( where: { id: i.id } ).results[0]
      expect( es_i.spam ).to be false
      user.add_flag( flag: Flag::SPAM, user_id: flagger.id )
      Delayed::Worker.new.work_off
      es_i = Identification.elastic_search( where: { id: i.id } ).results[0]
      expect( es_i.spam ).to be true
    end
    it "should reindex projects as spam" do
      project = Project.make!( user: user )
      Delayed::Worker.new.work_off
      es_project = Project.elastic_search( where: { id: project.id } ).results[0]
      expect( es_project.spam ).to be false
      user.add_flag( flag: Flag::SPAM, user_id: flagger.id )
      Delayed::Worker.new.work_off
      es_project = Project.elastic_search( where: { id: project.id } ).results[0]
      expect( es_project.spam ).to be true
    end
  end

  describe "description spam check" do
    it "should happen on create" do
      Rakismet.disabled = false
      user = User.make( description: "this is spam" )
      allow( user ).to receive(:spam?).and_return( true )
      user.save!
      expect( user ).to be_flagged_as_spam
    end
    it "should happen on update" do
      user = User.make!( description: "this is ok" )
      expect( user ).not_to be_flagged_as_spam
      Rakismet.disabled = false
      allow( user ).to receive(:spam?).and_return( true )
      user.update( description: "buy this watch!" )
      expect( user ).to be_flagged_as_spam
    end
  end

  describe "forget" do
    elastic_models( Observation )
    it "changes user_id in flags to -1" do
      f = Flag.make!
      other_f = Flag.make!
      flag_user_id = f.user.id
      expect( flag_user_id ).not_to be_blank
      User.forget( f.user_id, skip_aws: true )
      f.reload
      expect( f.user_id ).to eq -1
      other_f.reload
      expect( other_f.user_id ).to be > 0
    end

    it "removes the DeletedUser" do
      u = create :user
      user_id = u.id
      User.forget( user_id, skip_aws: true )
      expect( DeletedUser.where( user_id: user_id ).first ).to be_blank
    end
    it "removes EmailSuppressions associated with the user" do
      u = create :user
      user_id = u.id
      es = create :email_suppression, user: u
      User.forget( user_id, skip_aws: true )
      expect( EmailSuppression.find_by_id( es.id ) ).to be_blank
    end
    it "removes EmailSuppressions with matching emails not associated with the user" do
      u = create :user
      user_id = u.id
      email = u.email
      es = create :email_suppression, email: u.email
      expect( u.email_suppressions ).to be_blank
      User.forget( user_id, skip_aws: true )
      expect( EmailSuppression.find_by_email( email ) ).to be_blank
    end
  end

  describe "ip_address_is_often_suspended" do
    let( :ip ) { "127.0.0.1" }
    it "nils are OK" do
      expect( User.ip_address_is_often_suspended( nil ) ).to be false
    end

    it "uknown IPs are OK" do
      expect( User.where( last_ip: ip ).count ).to be 0
      expect( User.ip_address_is_often_suspended( ip ) ).to be false
    end

    it "unsuspended IPs are OK" do
      # 0 suspended, 10 active: 0% suspended, returns false
      10.times{ User.make!( last_ip: ip ) }
      expect( User.where( last_ip: ip ).count ).to be 10
      expect( User.ip_address_is_often_suspended( ip ) ).to be false
    end

    it "less than two total occurrences is OK" do
      # 2 suspended, 0 active: 100% suspended, but less than 3 total, returns false
      2.times{ User.make!( last_ip: ip, suspended_at: Time.now ) }
      expect( User.ip_address_is_often_suspended( ip ) ).to be false
    end

    it "three or more suspended accounts is not OK" do
      # 3 suspended, 0 active: 100% suspended, returns false
      3.times{ User.make!( last_ip: ip, suspended_at: Time.now ) }
      expect( User.ip_address_is_often_suspended( ip ) ).to be true
    end

    it "under 90% suspended is OK" do
      # 3 suspended, 1 active: 75% suspended, returns false
      3.times{ User.make!( last_ip: ip, suspended_at: Time.now ) }
      User.make!( last_ip: ip )
      expect( User.ip_address_is_often_suspended( ip ) ).to be false
    end

    it "returns true when over 90% of accounts are suspended" do
      # 9 suspended, 1 active: 90% suspended, returns true
      9.times{ User.make!( last_ip: ip, suspended_at: Time.now ) }
      User.make!( last_ip: ip )
      expect( User.ip_address_is_often_suspended( ip ) ).to be true
    end
  end

  describe "taxa_unobserved_before_date" do
    elastic_models( Observation )
    let( :user ) { User.make! }
    it "returns an empty array by default" do
      expect( user.taxa_unobserved_before_date( Date.today ) ).to eq []
    end

    it "returns taxa not observed by the user" do
      taxon = Taxon.make!
      expect( user.taxa_unobserved_before_date( Date.today, [taxon] ) ).to eq [taxon]
    end

    it "does not return taxa previously observed by the user" do
      taxon = Taxon.make!
      obs = Observation.make!(
        user: user,
        taxon: taxon,
        observed_on_string: 1.week.ago.to_s
      )
      expect( user.taxa_unobserved_before_date( Date.today, [taxon] ) ).to eq []
    end
  end

  describe "create_from_omniauth" do
    let(:email) { Faker::Internet.email }
    let(:auth_info) { {
      "info" => {
        "email" => email,
        "name" => Faker::Name.name
      },
      "extra" => {
        "user_hash" => {
          "email" => email
        }
      }
    } }
    it "should set the confirmation_token" do
      u = User.create_from_omniauth( auth_info )
      expect( u ).not_to be_confirmed
      expect( u.confirmation_token ).not_to be_blank
    end
    it "should send the confirmation email" do
      User.create_from_omniauth( auth_info )
      expect( ActionMailer::Base.deliveries.last.subject ).to include "Confirm"
    end
    describe "with an email in the name field" do
      let(:auth_info) { {
        "info" => {
          "email" => email,
          "name" => email
        },
        "extra" => {
          "user_hash" => {
            "email" => email
          }
        }
      } }
      it "should not allow an email in the name field" do
        u = User.create_from_omniauth( auth_info )
        expect( u.email ).to eq email
        expect( u.name ).not_to include email
      end
      it "should not automatically suggest something like the email in the name field" do
        u = User.create_from_omniauth( auth_info )
        expect( u.name ).to be_blank
      end
      it "should not automatically suggest something like the email in the login field" do
        email_login_suggestion = User.suggest_login( email )
        u = User.create_from_omniauth( auth_info )
        expect( u.login ).not_to include email_login_suggestion
      end
    end
  end

  describe "confirmation" do
    it "should deliver the welcome email when a new user is confirmed" do
      user = create :user, :as_unconfirmed, created_at: ( User::EMAIL_CONFIRMATION_RELEASE_DATE + 1.day )
      expect( ActionMailer::Base.deliveries.last.subject ).to include "Confirm"
      expect { user.confirm }.to change( ActionMailer::Base.deliveries, :size ).by( 1 )
      expect( ActionMailer::Base.deliveries.last.subject ).to include "Welcome"
    end
    it "should not deliver the welcome email when confirmation_sent_at is nil" do
      user = create :user
      user.update( confirmed_at: nil, confirmation_sent_at: nil )
      expect( user ).not_to be_confirmed
      expect { user.confirm }.not_to change( ActionMailer::Base.deliveries, :size )
    end
    it "should not deliver the welcome email when user created before release date" do
      user = create :user, :as_unconfirmed, created_at: ( User::EMAIL_CONFIRMATION_RELEASE_DATE - 1.day )
      create :user_privilege, user: user
      expect( user ).not_to be_confirmed
      expect( user.created_at ).to be < User::EMAIL_CONFIRMATION_RELEASE_DATE
      expect { user.confirm }.not_to change( ActionMailer::Base.deliveries, :size )
    end
  end

  protected
  def create_user(options = {})
    opts = {
      :login => 'quire',
      :email => 'quire@example.com',
      :password => 'quire69',
      :password_confirmation => 'quire69'
    }.merge(options)
    u = User.new(opts)
    u.save
    u
  end
end
