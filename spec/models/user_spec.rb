# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

# Be sure to include AuthenticatedTestHelper in spec/spec_helper.rb instead.
# Then, you can remove it from this and the functional test.
include AuthenticatedTestHelper

describe User do
  fixtures :users

  describe 'being created' do
    before do
      @user = nil
      @creating_user = lambda do
        @user = create_user
        violated "#{@user.errors.full_messages.to_sentence}" if @user.new_record?
      end
    end

    it 'increments User#count' do
      @creating_user.should change(User, :count).by(1)
    end

    it 'initializes #activation_code' do
      @creating_user.call
      @user.reload
      @user.activation_code.should_not be_nil
    end

    it 'starts in pending state' do
      @creating_user.call
      @user.reload
      @user.should be_pending
    end
    
    it 'should create a life list' do
      @creating_user.call
      @user.reload
      @user.life_list.should_not be_nil
    end
    
    it 'should create a life list that is among this users lists' do
      @creating_user.call
      @user.reload
      @user.lists.should include(@user.life_list)
    end
  end

  #
  # Validations
  #

  it 'requires login' do
    lambda do
      u = create_user(:login => nil)
      u.errors.on(:login).should_not be_nil
    end.should_not change(User, :count)
    
    lambda do
      u = create_user(:login => "")
      u.errors.on(:login).should_not be_nil
    end.should_not change(User, :count)
  end

  describe 'allows legitimate logins:' do
    ['whatisthewhat', 'zoooooolander', 'hello-_therefunnycharcom'].each do |login_str|
      it "'#{login_str}'" do
        lambda do
          u = create_user(:login => login_str)
          u.errors.on(:login).should     be_nil
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
          u.errors.on(:login).should_not be_nil
        end.should_not change(User, :count)
      end
    end
  end

  it 'requires password' do
    lambda do
      u = create_user(:password => nil)
      u.errors.on(:password).should_not be_nil
    end.should_not change(User, :count)
  end

  it 'requires password confirmation' do
    lambda do
      u = create_user(:password_confirmation => nil)
      u.errors.on(:password_confirmation).should_not be_nil
    end.should_not change(User, :count)
  end

  it 'requires email' do
    lambda do
      u = create_user(:email => nil)
      u.errors.on(:email).should_not be_nil
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
          u.errors.on(:email).should     be_nil
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
          u.errors.on(:email).should_not be_nil
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
          u.errors.on(:name).should     be_nil
        end.should change(User, :count).by(1)
      end
    end
  end
  describe "disallows illegitimate names" do
    ["tab\t", "newline\n",
     '1234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_234567890_',
     ].each do |name_str|
      it "'#{name_str}'" do
        lambda do
          u = create_user(:name => name_str)
          u.errors.on(:name).should_not be_nil
        end.should_not change(User, :count)
      end
    end
  end

  it 'resets password' do
    users(:quentin).update_attributes(:password => 'new password', :password_confirmation => 'new password')
    User.authenticate('quentin', 'new password').should == users(:quentin)
  end

  it 'does not rehash password' do
    users(:quentin).update_attributes(:login => 'quentin2')
    User.authenticate('quentin2', 'monkey').should == users(:quentin)
  end

  #
  # Authentication
  #

  it 'authenticates user' do
    User.authenticate('quentin', 'monkey').should == users(:quentin)
  end

  it "doesn't authenticate user with bad password" do
    User.authenticate('quentin', 'invalid_password').should be_nil
  end

 if REST_AUTH_SITE_KEY.blank?
   # old-school passwords
   it "authenticates a user against a hard-coded old-style password" do
     User.authenticate('old_password_holder', 'test').should == users(:old_password_holder)
   end
 else
   it "doesn't authenticate a user against a hard-coded old-style password" do
     User.authenticate('old_password_holder', 'test').should be_nil
   end

   # New installs should bump this up and set REST_AUTH_DIGEST_STRETCHES to give a 10ms encrypt time or so
   desired_encryption_expensiveness_ms = 0.1
   it "takes longer than #{desired_encryption_expensiveness_ms}ms to encrypt a password" do
     test_reps = 100
     start_time = Time.now; test_reps.times{ User.authenticate('quentin', 'monkey'+rand.to_s) }; end_time   = Time.now
     auth_time_ms = 1000 * (end_time - start_time)/test_reps
     auth_time_ms.should > desired_encryption_expensiveness_ms
   end
 end

  #
  # Authentication
  #

  it 'sets remember token' do
    users(:quentin).remember_me
    users(:quentin).remember_token.should_not be_nil
    users(:quentin).remember_token_expires_at.should_not be_nil
  end

  it 'unsets remember token' do
    users(:quentin).remember_me
    users(:quentin).remember_token.should_not be_nil
    users(:quentin).forget_me
    users(:quentin).remember_token.should be_nil
  end

  it 'remembers me for one week' do
    before = 6.days.from_now.utc
    users(:quentin).remember_me_for 1.week
    after = 8.days.from_now.utc
    
    users(:quentin).remember_token.should_not be_nil
    users(:quentin).remember_token_expires_at.should_not be_nil
    users(:quentin).remember_token_expires_at.between?(before, after).should be_true
  end

  it 'remembers me until one week' do
    time = 1.week.from_now
    users(:quentin).remember_me_until time
    users(:quentin).remember_token.should_not be_nil
    users(:quentin).remember_token_expires_at.should_not be_nil
    users(:quentin).remember_token_expires_at.to_i.should === time.to_i
  end

  it 'remembers me default two weeks' do
    Time.use_zone(users(:quentin).time_zone) do
      before = 13.days.from_now.utc
      users(:quentin).remember_me
      after = 15.days.from_now.utc
      users(:quentin).remember_token.should_not be_nil
      users(:quentin).remember_token_expires_at.should_not be_nil
      users(:quentin).remember_token_expires_at.between?(before, after).should be_true
    end
  end

  it 'registers passive user' do
    user = create_user(:password => nil, :password_confirmation => nil)
    user.should be_passive
    user.update_attributes(:password => 'new password', :password_confirmation => 'new password')
    user.register!
    user.should be_pending
  end

  it 'suspends user' do
    users(:quentin).suspend!
    users(:quentin).should be_suspended
  end

  it 'does not authenticate suspended user' do
    users(:quentin).suspend!
    User.authenticate('quentin', 'monkey').should_not == users(:quentin)
  end

  it 'deletes user' do
    users(:quentin).deleted_at.should be_nil
    users(:quentin).delete!
    users(:quentin).deleted_at.should_not be_nil
    users(:quentin).should be_deleted
  end
  
  describe "deletion" do
    it "should create a deleted user" do
      user = User.make
      user.destroy
      deleted_user = DeletedUser.last
      deleted_user.should_not be_blank
      deleted_user.user_id.should == user.id
      deleted_user.login.should == user.login
      deleted_user.email.should == user.email
    end
  end

  describe "being unsuspended" do
    fixtures :users

    before do
      @user = users(:quentin)
      @user.suspend!
    end

    it 'reverts to active state' do
      @user.unsuspend!
      @user.should be_active
    end

    it 'reverts to passive state if activation_code and activated_at are nil' do
      User.update_all :activation_code => nil, :activated_at => nil
      @user.reload.unsuspend!
      @user.should be_passive
    end

    it 'reverts to pending state if activation_code is set and activated_at is nil' do
      User.update_all :activation_code => 'foo-bar', :activated_at => nil
      @user.reload.unsuspend!
      @user.should be_pending
    end
  end
  
  describe "licenses" do
    it "should update existing observations if requested" do
      u = User.make
      o = Observation.make(:user => u)
      u.preferred_observation_license = Observation::CC_BY
      u.update_attributes(:make_observation_licenses_same => true)
      o.reload
      o.license.should == Observation::CC_BY
    end
    
    it "should update existing photo if requested" do
      u = User.make
      p = LocalPhoto.make(:user => u)
      u.preferred_photo_license = Observation::CC_BY
      u.update_attributes(:make_photo_licenses_same => true)
      p.reload
      p.license.should == Photo.license_number_for_code(Observation::CC_BY)
    end
  end

  protected
  def create_user(options = {})
    record = User.new({ :login => 'quire', :email => 'quire@example.com', :password => 'quire69', :password_confirmation => 'quire69' }.merge(options))
    record.register! if record.valid?
    record
  end
end


describe User, "merge" do
  before(:each) do
    @keeper = User.make
    @reject = User.make
  end
  it "should move observations" do
    o = Observation.make(:user => @reject)
    @keeper.merge(@reject)
    o.reload
    o.user_id.should == @keeper.id
  end
  
  it "should merge life lists" do
    t = Taxon.make
    @reject.life_list.add_taxon(t)
    @keeper.merge(@reject)
    @keeper.reload
    @keeper.life_list.taxon_ids.should include(t.id)
  end
  
  it "should remove self frienships" do
    f = Friendship.make(:user => @reject, :friend => @keeper)
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
