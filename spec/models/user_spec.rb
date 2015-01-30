# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

# Be sure to include AuthenticatedTestHelper in spec/spec_helper.rb instead.
# Then, you can remove it from this and the functional test.
include AuthenticatedTestHelper

describe User do
  describe 'creation' do
    before do
      @user = nil
      @creating_user = lambda do
        @user = create_user
        puts "[ERROR] #{@user.errors.full_messages.to_sentence}" if @user.new_record?
      end
    end

    it 'increments User#count' do
      @creating_user.should change(User, :count).by(1)
    end

    it 'initializes confirmation_token' do
      @creating_user.call
      @user.reload
      @user.confirmation_token.should_not be_blank
    end
    
    it 'should create a life list' do
      @creating_user.call
      @user.reload
      @user.life_list.should_not be_blank
    end
    
    it 'should create a life list that is among this users lists' do
      @creating_user.call
      @user.reload
      @user.lists.should include(@user.life_list)
    end
    
    it "should enforce unique login regardless of a case" do
      u1 = User.make!(:login => 'foo')
      lambda {
        User.make!(:login => 'FOO')
      }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should require email under normal circumstances" do
      u = User.make
      u.email = nil
      u.should_not be_valid
    end
    
    it "should allow skipping email validation" do
      u = User.make
      u.email = nil
      u.skip_email_validation = true
      u.should be_valid
    end

    it "should set the URI" do
      u = User.make!
      u.uri.should eq(FakeView.user_url(u))
    end

    it "should set a default locale" do
      u = User.make!
      u.locale.should eq I18n.locale.to_s
    end

    it "should strip the login" do
      u = User.make(:login => "foo ")
      u.save
      u.login.should eq "foo"
      u.should be_valid
    end

    it "should strip the email" do
      u = User.make(:email => "foo@bar.com ")
      u.save
      u.email.should eq "foo@bar.com"
      u.should be_valid
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
    ['12', '123', '1234567890_234567890_234567890_234567890_',
     "Iñtërnâtiônàlizætiøn hasn't happened to ruby 1.8 yet",
     'semicolon;', 'quote"', 'tick\'', 'backtick`', 'percent%', 'plus+', 
     'period.', 'm', 
     'this_is_the_longest_login_ever_written_by_man'].each do |login_str|
      it "'#{login_str}'" do
        expect {
          u = create_user(:login => login_str)
          expect(u.errors[:login]).to_not be_blank
        }.to_not change(User, :count)
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
        lambda do
          u = create_user(:email => email_str)
          u.errors[:email].should     be_blank
        end.should change(User, :count).by(1)
      end
    end
  end
  # describe 'disallows illegitimate emails' do
  #   ['!!@nobadchars.com', 'foo@no-rep-dots..com', 'foo@badtld.xxx', 'foo@toolongtld.abcdefg',
  #    'Iñtërnâtiônàlizætiøn@hasnt.happened.to.email', 'need.domain.and.tld@de', "tab\t", "newline\n",
  #    'r@.wk', '1234567890-234567890-234567890-234567890-234567890-234567890-234567890-234567890-234567890@gmail2.com',
  #    # these are technically allowed but not seen in practice:
  #    'uucp!addr@gmail.com', 'semicolon;@gmail.com', 'quote"@gmail.com', 'tick\'@gmail.com', 'backtick`@gmail.com', 'space @gmail.com', 'bracket<@gmail.com', 'bracket>@gmail.com'
  #   ].each do |email_str|
  #     it "'#{email_str}'" do
  #       lambda do
  #         u = create_user(:email => email_str)
  #         u.errors[:email].should_not be_blank
  #       end.should_not change(User, :count)
  #     end
  #   end
  # end

  describe 'allows legitimate names:' do
    ['Andre The Giant (7\'4", 520 lb.) -- has a posse',
     '', '1234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890',
    ].each do |name_str|
      it "'#{name_str}'" do
        lambda do
          u = create_user(:name => name_str)
          u.errors[:name].should     be_blank
        end.should change(User, :count).by(1)
      end
    end
  end
  describe "disallows illegitimate names" do
    [
     '1234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_'
     ].each do |name_str|
      it "'#{name_str}'" do
        lambda do
          u = create_user(:name => name_str)
          u.errors[:name].should_not be_blank
        end.should_not change(User, :count)
      end
    end
  end

  it 'resets password' do
    user = User.make!
    user.update_attributes(:password => 'new password', :password_confirmation => 'new password')
    User.authenticate(user.login, 'new password').should == user
  end

  it 'does not rehash password' do
    pw = "fooosdgsg"
    user = User.make!(:password => pw, :password_confirmation => pw)
    user.update_attributes(:login => 'quentin2')
    User.authenticate('quentin2', pw).should == user
  end

  describe "authentication" do
    before(:each) do
      @pw = "fooosdgsg"
      @user = User.make!(:password => @pw, :password_confirmation => @pw)
    end

    it 'authenticates user' do
      User.authenticate(@user.login, @pw).should == @user
    end

    it "doesn't authenticate user with bad password" do
      User.authenticate(@user.login, 'invalid_password').should be_blank
    end

    it 'does not authenticate suspended user' do
      @user.suspend!
      User.authenticate(@user.login, @pw).should_not == @user
    end
  end

  describe "remembering" do
    before(:each) do
      @user = User.make!
    end

    it 'sets remember token' do
      @user.remember_me!
      @user.remember_token.should_not be_blank
      @user.remember_expires_at.should_not be_blank
    end

    it 'unsets remember token' do
      @user.remember_me!
      @user.remember_token.should_not be_blank
      @user.forget_me!
      @user.remember_token.should be_blank
    end

    it 'remembers me default two weeks' do
      Time.use_zone(@user.time_zone) do
        before = 13.days.from_now.utc
        @user.remember_me!
        after = 15.days.from_now.utc
        @user.remember_token.should_not be_blank
        @user.remember_expires_at.should_not be_blank
        expect(@user.remember_expires_at.between?(before, after)).to be true
      end
    end
  end

  it 'suspends user' do
    user = User.make!
    user.suspend!
    user.should be_suspended
  end
  
  describe "deletion" do
    before do
      @user = User.make!
    end

    it "should create a deleted user" do
      @user.destroy
      deleted_user = DeletedUser.last
      deleted_user.should_not be_blank
      deleted_user.user_id.should == @user.id
      deleted_user.login.should == @user.login
      deleted_user.email.should == @user.email
    end
  end

  describe "sane_destroy" do
    before(:each) do
      without_delay do
        @user = User.make!
        @place = make_place_with_geom
        3.times do
          Observation.make!(:user => @user, :taxon => Taxon.make!, 
            :latitude => @place.latitude, :longitude => @place.longitude)
        end
      end
    end

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
      jobs.select{|j| j.handler =~ /'CheckList'.*\:refresh/m}.should_not be_blank
    end

    it "should refresh check lists" do
      t = Taxon.make!(rank: "species")
      without_delay do
        make_research_grade_observation(taxon: t , user: @user,
          latitude: @place.latitude, longitude: @place.longitude)
      end
      @place.check_list.listed_taxa.find_by_taxon_id(t.id).should_not be_blank
      without_delay do
        @user.sane_destroy
      end
      @place.check_list.listed_taxa.find_by_taxon_id(t.id).should be_blank
    end

    it "should queue jobs to refresh project lists" do
      project = without_delay {Project.make!(:user => @user)}
      project.project_list.should_not be_blank
      Delayed::Job.delete_all
      @user.sane_destroy
      jobs = Delayed::Job.all
      # jobs.map(&:handler).each{|h| puts h}
      jobs.select{|j| j.handler =~ /'ProjectList'.*\:refresh/m}.should_not be_blank
    end

    it "should remove remove taxa from check lists that were only confirmed by the user's observations" do
      o = without_delay do
        make_research_grade_observation(:user => @user, :latitude => @place.latitude, :longitude => @place.longitude)
      end
      t = o.taxon
      ListedTaxon.where(:place_id => @place, :taxon_id => t).should_not be_blank
      without_delay { @user.sane_destroy }
      ListedTaxon.where(:place_id => @place, :taxon_id => t).should be_blank
    end

    it "should destroy projects with no observations" do
      p = Project.make!(:user => @user)
      @user.sane_destroy
      Project.find_by_id(p.id).should be_blank
    end

    it "should not destroy projects with observations" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      @user.sane_destroy
      Project.find_by_id(p.id).should_not be_blank
    end

    it "should assign projects to a manager" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      m = ProjectUser.make!(:role => ProjectUser::MANAGER, :project => p)
      @user.sane_destroy
      p.reload
      p.user_id.should eq(m.user_id)
    end

    it "should assign projects to a site admin if no manager" do
      a = make_admin
      User.admins.count.should eq(1)
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      @user.sane_destroy
      p.reload
      p.user_id.should eq(a.id)
    end

    it "should generate a notification update for new project owners" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      m = without_delay do
        ProjectUser.make!(:role => ProjectUser::MANAGER, :project => p)
      end
      Update.delete_all
      old_count = Update.count
      start = Time.now
      without_delay { @user.sane_destroy }
      new_updates = Update.where("created_at >= ?", start).to_a
      new_updates.size.should eq p.project_users.count
      # new_updates.each{|u| puts "u.subscriber_id: #{u.subscriber_id}, u.notification: #{u.notification}"}
      u = new_updates.detect{|o| o.subscriber_id == m.user_id}
      u.should_not be_blank
      u.resource.should eq(p)
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
      new_updates.size.should eq p.project_users.count
      # new_updates.each{|u| puts "u.subscriber_id: #{u.subscriber_id}, u.notification: #{u.notification}"}
      u = new_updates.detect{|o| o.subscriber_id == a.id}
      u.should_not be_blank
      u.resource.should eq(p)
    end

    it "should not destroy project journal posts" do
      p = Project.make!(:user => @user)
      po = make_project_observation(:project => p)
      pjp = Post.make!(:parent => p, :user => @user)
      @user.sane_destroy
      Post.find_by_id(pjp.id).should_not be_blank
    end
  end

  describe "suspension" do
    it "deletes unread sent messages" do
      fu = User.make!
      tu = User.make!
      m = make_message(:user => fu, :from_user => fu, :to_user => tu)
      m.send_message
      m.to_user_copy.should_not be_blank
      fu.suspend!
      m.reload
      m.to_user_copy.should be_blank
    end

    it "should not delete the suspended user's messages" do
      fu = User.make!
      tu = User.make!
      m = make_message(:user => fu, :from_user => fu, :to_user => tu)
      m.send_message
      m.to_user_copy.should_not be_blank
      fu.suspend!
      Message.find_by_id(m.id).should_not be_blank
    end
  end

  describe "being unsuspended" do

    before do
      @user = User.make!
      @user.suspend!
    end

    it 'reverts to active state' do
      @user.unsuspend!
      @user.should be_active
    end
  end
  
  describe "licenses" do
    it "should update existing observations if requested" do
      u = User.make!
      o = Observation.make!(:user => u)
      u.preferred_observation_license = Observation::CC_BY
      u.update_attributes(:make_observation_licenses_same => true)
      o.reload
      o.license.should == Observation::CC_BY
    end
    
    it "should update existing photo if requested" do
      u = User.make!
      p = LocalPhoto.make!(:user => u)
      u.preferred_photo_license = Observation::CC_BY
      u.update_attributes(:make_photo_licenses_same => true)
      p.reload
      p.license.should == Photo.license_number_for_code(Observation::CC_BY)
    end

    it "should not update GoogleStreetViewPhotos" do
      u = User.make!
      p = GoogleStreetViewPhoto.make!(:user => u)
      u.preferred_photo_license = Observation::CC_BY
      u.update_attributes(:make_photo_licenses_same => true)
      p.reload
      p.license.should == Photo::COPYRIGHT
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


describe User, "merge" do
  before(:each) do
    @keeper = User.make!
    @reject = User.make!
  end
  
  it "should move observations" do
    o = Observation.make!(:user => @reject)
    without_delay do
      @keeper.merge(@reject)
    end
    o.reload
    o.user_id.should == @keeper.id
  end
  
  it "should merge life lists" do
    t = Taxon.make!
    @reject.life_list.add_taxon(t)
    @keeper.merge(@reject)
    @keeper.reload
    @keeper.life_list.taxon_ids.should include(t.id)
  end
  
  it "should remove self frienships" do
    f = Friendship.make!(:user => @reject, :friend => @keeper)
    @keeper.merge(@reject)
    Friendship.find_by_id(f.id).should be_blank
    @keeper.friendships.map(&:friend_id).should_not include(@keeper.id)
  end
  
  it "should queue a job to refresh the keeper's life list" do
    Delayed::Job.delete_all
    stamp = Time.now
    @keeper.merge(@reject)
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    # puts jobs.map(&:handler).inspect
    jobs.select{|j| j.handler =~ /LifeList.*\:reload_from_observations/m}.should_not be_blank
  end
end

describe User, "suggest_login" do
  it "should suggest logins that are too short" do
    suggestion = User.suggest_login("AJ")
    suggestion.should_not be_blank
    suggestion.size.should be >= User::MIN_LOGIN_SIZE
  end
  
  it "should not suggests logins that are too big" do
    suggestion = User.suggest_login("Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor")
    suggestion.should_not be_blank
    suggestion.size.should be <= User::MAX_LOGIN_SIZE
  end
end

describe User, "community taxa preference" do
  it "should not remove community taxa when set to false" do
    o = Observation.make!
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.community_taxon.should eq i1.taxon
    o.user.update_attributes(:prefers_community_taxa => false)
    Delayed::Worker.new.work_off
    o.reload
    o.taxon.should be_blank
  end

  it "should set observation taxa to owner's ident when set to false" do
    owners_taxon = Taxon.make!
    o = Observation.make!(:taxon => owners_taxon)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    i3 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.taxon.should eq o.community_taxon
    o.user.update_attributes(:prefers_community_taxa => false)
    Delayed::Worker.new.work_off
    o.reload
    o.taxon.should eq owners_taxon
  end

  it "should not set observation taxa to owner's ident when set to false for observations that prefer community taxon" do
    owners_taxon = Taxon.make!
    o = Observation.make!(:taxon => owners_taxon, :prefers_community_taxon => true)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    i3 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.taxon.should eq o.community_taxon
    o.user.update_attributes(:prefers_community_taxa => false)
    Delayed::Worker.new.work_off
    o.reload
    o.taxon.should eq o.community_taxon
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
