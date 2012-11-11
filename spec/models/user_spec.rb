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
  end

  #
  # Validations
  #

  it 'requires login' do
    lambda do
      u = create_user(:login => nil)
      u.errors[:login].should_not be_blank
    end.should_not change(User, :count)
    
    lambda do
      u = create_user(:login => "")
      u.errors[:login].should_not be_blank
    end.should_not change(User, :count)
  end

  describe 'allows legitimate logins:' do
    ['whatisthewhat', 'zoooooolander', 'hello-_therefunnycharcom'].each do |login_str|
      it "'#{login_str}'" do
        lambda do
          u = create_user(:login => login_str)
          u.errors[:login].should     be_blank
        end.should change(User, :count).by(1)
      end
    end
  end
  describe 'disallows illegitimate logins:' do
    ['12', '123', '1234567890_234567890_234567890_234567890_', "tab\t", "newline\n",
     "Iñtërnâtiônàlizætiøn hasn't happened to ruby 1.8 yet",
     'semicolon;', 'quote"', 'tick\'', 'backtick`', 'percent%', 'plus+', 
     'space ', 'period.', 'm', 
     'this_is_the_longest_login_ever_written_by_man'].each do |login_str|
      it "'#{login_str}'" do
        lambda do
          u = create_user(:login => login_str)
          u.errors[:login].should_not be_blank
        end.should_not change(User, :count)
      end
    end
  end

  it 'requires password' do
    lambda do
      u = create_user(:password => nil)
      u.errors[:password].should_not be_blank
    end.should_not change(User, :count)
  end

  it 'requires password confirmation' do
    lambda do
      u = create_user(:password_confirmation => "")
      u.errors[:password].should_not be_blank
    end.should_not change(User, :count)
  end

  it 'requires email' do
    lambda do
      u = create_user(:email => nil)
      u.errors[:email].should_not be_blank
    end.should_not change(User, :count)
  end

  describe 'allows legitimate emails:' do
    ['foo@bar.com', 'foo@newskool-tld.museum', 'foo@twoletter-tld.de', 'foo@nonexistant-tld.qq',
     'r@a.wk', '1234567890-234567890-234567890-234567890-234567890-234567890-234567890-234567890-234567890@gmail.com',
     'hello.-_there@funnychar.com', 'uucp%addr@gmail.com', 'hello+routing-str@gmail.com',
     'domain@can.haz.many.sub.doma.in', 'student.name@university.edu'
    ].each do |email_str|
      it "'#{email_str}'" do
        lambda do
          u = create_user(:email => email_str)
          u.errors[:email].should     be_blank
        end.should change(User, :count).by(1)
      end
    end
  end
  describe 'disallows illegitimate emails' do
    ['!!@nobadchars.com', 'foo@no-rep-dots..com', 'foo@badtld.xxx', 'foo@toolongtld.abcdefg',
     'Iñtërnâtiônàlizætiøn@hasnt.happened.to.email', 'need.domain.and.tld@de', "tab\t", "newline\n",
     'r@.wk', '1234567890-234567890-234567890-234567890-234567890-234567890-234567890-234567890-234567890@gmail2.com',
     # these are technically allowed but not seen in practice:
     'uucp!addr@gmail.com', 'semicolon;@gmail.com', 'quote"@gmail.com', 'tick\'@gmail.com', 'backtick`@gmail.com', 'space @gmail.com', 'bracket<@gmail.com', 'bracket>@gmail.com'
    ].each do |email_str|
      it "'#{email_str}'" do
        lambda do
          u = create_user(:email => email_str)
          u.errors[:email].should_not be_blank
        end.should_not change(User, :count)
      end
    end
  end

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
        @user.remember_expires_at.between?(before, after).should be_true
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

  describe "being unsuspended" do

    before do
      @user = User.make!
      @user.suspend!
    end

    it 'reverts to active state' do
      @user.unsuspend!
      @user.should be_active
    end

    # it 'reverts to passive state if activation_code and activated_at are nil' do
    #   User.update_all :activation_code => nil, :activated_at => nil
    #   @user.reload.unsuspend!
    #   @user.should be_passive
    # end

    # it 'reverts to pending state if activation_code is set and activated_at is nil' do
    #   User.update_all :activation_code => 'foo-bar', :activated_at => nil
    #   @user.reload.unsuspend!
    #   @user.should be_pending
    # end
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
    @keeper.merge(@reject)
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
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
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
