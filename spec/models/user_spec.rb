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
  "password", "new"
]

describe User do
  before(:all) do
    DatabaseCleaner.clean_with(:truncation, except: %w[spatial_ref_sys])
  end

  describe 'creation' do
    before do
      @user = nil
      @creating_user = lambda do
        @user = create_user
        puts "[ERROR] #{@user.errors.full_messages.to_sentence}" if @user.new_record?
      end
    end

    it 'increments User#count' do
      expect(@creating_user).to change(User, :count).by(1)
    end

    it 'initializes confirmation_token' do
      @creating_user.call
      @user.reload
      expect(@user.confirmation_token).not_to be_blank
    end
    
    it 'should create a life list' do
      @creating_user.call
      @user.reload
      expect(@user.life_list).not_to be_blank
    end
    
    it 'should create a life list that is among this users lists' do
      @creating_user.call
      @user.reload
      expect(@user.lists).to include(@user.life_list)
    end
    
    it "should enforce unique login regardless of a case" do
      u1 = User.make!(:login => 'foo')
      expect {
        User.make!(:login => 'FOO')
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should require email under normal circumstances" do
      u = User.make
      u.email = nil
      expect(u).not_to be_valid
    end
    
    it "should allow skipping email validation" do
      u = User.make
      u.email = nil
      u.skip_email_validation = true
      expect(u).to be_valid
    end

    it "should set the URI" do
      u = User.make!
      expect(u.uri).to eq(FakeView.user_url(u))
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

    it "should allow time_zone to be nil" do
      expect( User.make( time_zone: nil ) ).to be_valid
    end

    it "should not allow time_zone to be a blank string" do
      expect( User.make( time_zone: "" ) ).not_to be_valid
    end
  end

  describe "update" do
    before(:each) { enable_elastic_indexing( Observation ) }
    after(:each) { disable_elastic_indexing( Observation ) }
    
    it "should update the site_id on the user's observations" do
      s1 = Site.make!
      s2 = Site.make!
      u = User.make!(site: s1)
      o = Observation.make!(user: u, site: s1)
      without_delay { u.update_attributes(site: s2) }
      o.reload
      expect( o.site ).to eq s2
    end

    it "should update the site_id in the elastic index" do
      s1 = Site.make!
      s2 = Site.make!
      u = User.make!(site: s1)
      o = Observation.make!(user: u, site: s1)
      without_delay { u.update_attributes(site: s2) }
      o.reload
      es_o = Observation.elastic_paginate(where: {site_id: s2.id}).first
      expect( es_o ).to eq o
    end
  end

  #
  # Validations
  #

  it 'requires login' do
    expect {
      u = create_user(:login => nil)
      expect(u.errors[:login]).to_not be_blank
    }.to_not change(User, :count)
    
    expect {
      u = create_user(:login => "")
      expect(u.errors[:login]).to_not be_blank
    }.to_not change(User, :count)
  end

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

  it 'requires password' do
    expect {
      u = create_user(:password => nil)
      expect(u.errors[:password]).to_not be_blank
    }.to_not change(User, :count)
  end

  it 'requires password confirmation' do
    expect {
      u = create_user(:password_confirmation => "")
      expect(u.errors[:password_confirmation]).to_not be_blank
    }.to_not change(User, :count)
  end

  it 'requires email' do
    expect {
      u = create_user(:email => nil)
      expect(u.errors[:email]).to_not be_blank
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
    user.update_attributes(:password => 'new password', :password_confirmation => 'new password')
    expect(User.authenticate(user.login, 'new password')).to eq user
  end

  it 'does not rehash password' do
    pw = "fooosdgsg"
    user = User.make!(:password => pw, :password_confirmation => pw)
    user.update_attributes(:login => 'quentin2')
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
  end

  describe "sane_destroy" do
    before(:all) { DatabaseCleaner.strategy = :truncation }
    after(:all)  { DatabaseCleaner.strategy = :transaction }

    before(:each) do
      enable_elastic_indexing([ Observation, Taxon, Place, Update ])
      without_delay do
        @user = User.make!
        @place = make_place_with_geom
        3.times do
          Observation.make!(:user => @user, :taxon => Taxon.make!, 
            :latitude => @place.latitude, :longitude => @place.longitude)
        end
      end
    end
    after(:each) { disable_elastic_indexing([ Observation, Place, Update ]) }

    it "should destroy the user" do
      @user.sane_destroy
      expect(User.find_by_id(@user.id)).to be_blank
    end

    it "should not queue jobs to refresh the users lists" do
      Delayed::Job.delete_all
      @user.sane_destroy
      jobs = Delayed::Job.all
      # jobs.map(&:handler).each{|h| puts h}
      expect(jobs.select{ |j| j.handler =~ /'List'.*\:refresh/m }).to be_blank
    end

    it "should not queue refresh_with_observation jobs" do
      Delayed::Job.delete_all
      @user.sane_destroy
      expect(Delayed::Job.all.select{ |j| j.handler =~ /refresh_with_observation/m }).to be_blank
    end

    it "should queue jobs to refresh check lists" do
      Delayed::Job.delete_all
      @user.sane_destroy
      jobs = Delayed::Job.all
      # jobs.map(&:handler).each{|h| puts h}
      expect(jobs.select{|j| j.handler =~ /'CheckList'.*\:refresh/m}).not_to be_blank
    end

    it "should refresh check lists" do
      t = Taxon.make!(rank: "species")
      o = without_delay do
        make_research_grade_observation(taxon: t , user: @user,
          latitude: @place.latitude, longitude: @place.longitude)
      end
      expect(@place.check_list.listed_taxa.find_by_taxon_id(t.id)).not_to be_blank
      @user.sane_destroy
      Delayed::Worker.new.work_off
      expect( Observation.find_by_id(o.id) ).to be_blank
      expect(@place.check_list.listed_taxa.find_by_taxon_id(t.id)).to be_blank
    end

    it "should queue jobs to refresh project lists" do
      project = without_delay {Project.make!(:user => @user)}
      expect(project.project_list).not_to be_blank
      Delayed::Job.delete_all
      @user.sane_destroy
      jobs = Delayed::Job.all
      # jobs.map(&:handler).each{|h| puts h}
      expect(jobs.select{|j| j.handler =~ /'ProjectList'.*\:refresh/m}).not_to be_blank
    end

    it "should remove remove taxa from check lists that were only confirmed by the user's observations" do
      o = without_delay do
        make_research_grade_observation(:user => @user, :latitude => @place.latitude, :longitude => @place.longitude)
      end
      t = o.taxon
      expect(ListedTaxon.where(:place_id => @place, :taxon_id => t)).not_to be_blank
      @user.sane_destroy
      Delayed::Worker.new.work_off
      expect(ListedTaxon.where(:place_id => @place, :taxon_id => t)).to be_blank
    end

    it "should destroy projects with no observations" do
      p = Project.make!(:user => @user)
      @user.sane_destroy
      expect(Project.find_by_id(p.id)).to be_blank
    end

    it "should not destroy projects with observations" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      @user.sane_destroy
      expect(Project.find_by_id(p.id)).not_to be_blank
    end

    it "should assign projects to a manager" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      m = ProjectUser.make!(:role => ProjectUser::MANAGER, :project => p)
      @user.sane_destroy
      p.reload
      expect(p.user_id).to eq(m.user_id)
    end

    it "should assign projects to a site admin if no manager" do
      a = make_admin
      expect(User.admins.count).to eq(1)
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      @user.sane_destroy
      p.reload
      expect(p.user_id).to eq(a.id)
    end

    it "should generate a notification update for new project owners" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      m = without_delay do
        ProjectUser.make!(:role => ProjectUser::MANAGER, :project => p)
      end
      Update.destroy_all
      old_count = Update.count
      start = Time.now
      without_delay { @user.sane_destroy }
      new_updates = Update.where("created_at >= ?", start).to_a
      expect(new_updates.size).to eq p.project_users.count
      # new_updates.each{|u| puts "u.subscriber_id: #{u.subscriber_id}, u.notification: #{u.notification}"}
      u = new_updates.detect{|o| o.subscriber_id == m.user_id}
      expect(u).not_to be_blank
      expect(u.resource).to eq(p)
    end

    it "should generate a notification update for new project owners even if they're new members" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      a = without_delay do
        make_admin
      end
      Update.delete_all
      old_count = Update.count
      start = Time.now

      without_delay { @user.sane_destroy }
      p.reload
      new_updates = Update.where("created_at >= ?", start).to_a
      expect(new_updates.size).to eq p.project_users.count
      # new_updates.each{|u| puts "u.subscriber_id: #{u.subscriber_id}, u.notification: #{u.notification}"}
      u = new_updates.detect{|o| o.subscriber_id == a.id}
      expect(u).not_to be_blank
      expect(u.resource).to eq(p)
    end

    it "should not destroy project journal posts" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      pjp = Post.make!(:parent => p, :user => @user)
      @user.sane_destroy
      expect(Post.find_by_id(pjp.id)).not_to be_blank
    end

    it "should reassess the community taxon of observations the user has identified" do
      o = make_research_grade_candidate_observation(taxon: Taxon.make!(rank: Taxon::SPECIES))
      expect( o.community_taxon ).to be_blank
      i = Identification.make!(observation: o, taxon: o.taxon, user: @user)
      o.reload
      expect( o.community_taxon ).to eq i.taxon
      @user.sane_destroy
      o.reload
      expect( o.community_taxon ).to be_blank
    end

    it "should reassess the quality grade of observations the user has identified" do
      o = make_research_grade_candidate_observation(taxon: Taxon.make!(rank: Taxon::SPECIES))
      expect( o.quality_grade ).to eq Observation::NEEDS_ID
      i = Identification.make!(observation: o, taxon: o.taxon, user: @user)
      o.reload
      expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      without_delay { @user.sane_destroy }
      o.reload
      expect( o.quality_grade ).to eq Observation::NEEDS_ID
    end
  end

  describe "suspension" do
    it "deletes unread sent messages" do
      fu = User.make!
      tu = User.make!
      m = make_message(:user => fu, :from_user => fu, :to_user => tu)
      m.send_message
      expect(m.to_user_copy).not_to be_blank
      fu.suspend!
      m.reload
      expect(m.to_user_copy).to be_blank
    end

    it "should not delete the suspended user's messages" do
      fu = User.make!
      tu = User.make!
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
    before(:each) { enable_elastic_indexing([ Observation ]) }
    after(:each) { disable_elastic_indexing([ Observation ]) }

    it "should update existing observations if requested" do
      u = User.make!
      o = Observation.make!(:user => u)
      u.preferred_observation_license = Observation::CC_BY
      u.update_attributes(:make_observation_licenses_same => true)
      o.reload
      expect(o.license).to eq Observation::CC_BY
    end
    
    it "should update existing photo if requested" do
      u = User.make!
      p = LocalPhoto.make!(:user => u)
      u.preferred_photo_license = Observation::CC_BY
      u.update_attributes(:make_photo_licenses_same => true)
      p.reload
      expect(p.license).to eq Photo.license_number_for_code(Observation::CC_BY)
    end

    it "should not update GoogleStreetViewPhotos" do
      u = User.make!
      p = GoogleStreetViewPhoto.make!(:user => u)
      u.preferred_photo_license = Observation::CC_BY
      u.update_attributes(:make_photo_licenses_same => true)
      p.reload
      expect(p.license).to eq Photo::COPYRIGHT
    end
  end

  describe "merge" do
    before(:each) do
      @keeper = User.make!
      @reject = User.make!
      enable_elastic_indexing( Observation )
    end
    after(:each) { disable_elastic_indexing( Observation ) }

    it "should move observations" do
      o = Observation.make!(:user => @reject)
      without_delay do
        @keeper.merge(@reject)
      end
      o.reload
      expect(o.user_id).to eq @keeper.id
    end

    it "should merge life lists" do
      t = Taxon.make!
      @reject.life_list.add_taxon(t)
      @keeper.merge(@reject)
      @keeper.reload
      expect(@keeper.life_list.taxon_ids).to include(t.id)
    end

    it "should remove self frienships" do
      f = Friendship.make!(:user => @reject, :friend => @keeper)
      @keeper.merge(@reject)
      expect(Friendship.find_by_id(f.id)).to be_blank
      expect(@keeper.friendships.map(&:friend_id)).not_to include(@keeper.id)
    end

    it "should queue a job to refresh the keeper's life list" do
      Delayed::Job.delete_all
      stamp = Time.now
      @keeper.merge(@reject)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      # puts jobs.map(&:handler).inspect
      expect(jobs.select{|j| j.handler =~ /LifeList.*\:reload_from_observations/m}).not_to be_blank
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
  end

  describe "community taxa preference" do
    it "should not remove community taxa when set to false" do
      o = Observation.make!
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).to eq i1.taxon
      o.user.update_attributes(:prefers_community_taxa => false)
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
      o.user.update_attributes(:prefers_community_taxa => false)
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
      o.user.update_attributes(:prefers_community_taxa => false)
      Delayed::Worker.new.work_off
      o.reload
      expect(o.taxon).to eq o.community_taxon
    end

    it "should change observation taxa to community taxa when set to true" do
      o = Observation.make!
      o.user.update_attributes(:prefers_community_taxa => false)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to be_blank
      o.user.update_attributes(:prefers_community_taxa => true)
      Delayed::Worker.new.work_off
      o.reload
      expect(o.taxon).to eq o.community_taxon
    end
  end

  describe "updating" do
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
    it "can prefer to not get mentions" do
      u = User.make!
      expect( u.updates.count ).to eq 0
      without_delay { Comment.make!(body: "hey @#{ u.login }") }
      without_delay { Comment.make!(body: "hey @#{ u.login }") }
      expect( u.updates.count ).to eq 2
      u.update_attributes(prefers_receive_mentions: false)
      without_delay { Comment.make!(body: "hey @#{ u.login }") }
      # the mention count remains the same
      expect( u.updates.count ).to eq 2
    end

    it "can prefer to not get mentions in emails" do
      u = User.make!
      expect( u.updates.count ).to eq 0
      without_delay { Comment.make!(body: "hey @#{ u.login }") }
      expect( u.updates.count ).to eq 1
      deliveries = ActionMailer::Base.deliveries.size
      u.update_attributes(prefers_mention_email_notification: false)
      Update.email_updates_to_user(u, 1.hour.ago, Time.now)
      expect( ActionMailer::Base.deliveries.size ).to eq deliveries
      u.update_attributes(prefers_mention_email_notification: true)
      Update.email_updates_to_user(u, 1.hour.ago, Time.now)
      expect( ActionMailer::Base.deliveries.size ).to eq (deliveries + 1)
    end
  end

  describe "prefers_redundant_identification_notifications" do
    before(:each) { enable_elastic_indexing( Observation, Update ) }
    after(:each) { disable_elastic_indexing( Observation, Update ) }

    let(:u) { User.make! }
    let(:genus) { Taxon.make!(rank: Taxon::GENUS) }
    let(:species) { Taxon.make!(rank: Taxon::SPECIES, parent: genus) }
    let(:subspecies) { Taxon.make!(rank: Taxon::SUBSPECIES, parent: species) }
    let(:o) { Observation.make!(taxon: species) }
    let(:i) { Identification.make!(observation: o, user: u, taxon: species)}

    describe "true" do
      before do
        u.update_attributes(prefers_redundant_identification_notifications: true)
        expect( i ).to be_persisted
        expect( u.subscriptions.map(&:resource) ).to include o
      end
      it "should allow identifications that match with the subscriber" do
        without_delay { Identification.make!(observation: o, taxon: species) }
        expect( u.updates.count ).to eq 1
      end
      it "should allow identifications of taxa that are descendants of the subscriber's taxon" do
        without_delay { Identification.make!(observation: o, taxon: subspecies) }
        expect( u.updates.count ).to eq 1
      end
      it "should allow identifications of taxa that are ancestors of the subscriber's taxon" do
        without_delay { Identification.make!(observation: o, taxon: genus) }
        expect( u.updates.count ).to eq 1
      end
    end

    describe "false" do
      before do
        u.update_attributes(prefers_redundant_identification_notifications: false)
        expect( i ).to be_persisted
        expect( u.subscriptions.map(&:resource) ).to include o
      end
      it "should suppress identifications that match with the subscriber" do
        without_delay { Identification.make!(observation: o, taxon: species) }
        expect( u.updates.count ).to eq 0
      end
      it "should allow identifications of taxa that are descendants of the subscriber's taxon" do
        without_delay { Identification.make!(observation: o, taxon: subspecies) }
        expect( u.updates.count ).to eq 1
      end
      it "should allow identifications of taxa that are ancestors of the subscriber's taxon" do
        without_delay { Identification.make!(observation: o, taxon: genus) }
        expect( u.updates.count ).to eq 1
      end
      it "should allow notification if subscriber has no identification" do
        obs = Observation.make!(user: u)
        expect( obs.owners_identification ).to be_blank
        without_delay { Identification.make!(observation: obs) }
        expect( u.updates.count ).to eq 1
      end
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
