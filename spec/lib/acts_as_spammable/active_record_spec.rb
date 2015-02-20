require "spec_helper"

describe "ActsAsSpammable", "ActiveRecord" do

  before(:all) do
    @user = User.make!
    Rakismet.disabled = false
  end

  after(:all) do
    Rakismet.disabled = true
  end

  it "recognizes spam" do
    Rakismet.should_receive(:akismet_call).and_return("true")
    o = Observation.make!(user: @user)
    o.spam?.should == true
  end

  it "recognizes non-spam" do
    o = Observation.make!(user: @user)
    o.spam?.should == false
  end

  it "knows when it has been flagged as spam" do
    o = Observation.make!(user: @user)
    o.flagged_as_spam?.should == false
    Flag.make!(flaggable: o, flag: Flag::SPAM)
    o.flagged_as_spam?.should == true
  end

  it "resolved flags are not spam" do
    o = Observation.make!(user: @user)
    o.flagged_as_spam?.should == false
    f = Flag.make!(flaggable: o, flag: Flag::SPAM)
    o.flagged_as_spam?.should == true
    Flag.last.update_attributes(resolved: true, resolver: @user)
    o.flagged_as_spam?.should == false
  end

  it "does not check for spam unless a spammable field is modified" do
    Rakismet.should_receive(:akismet_call).and_return("true")
    o = Observation.make!(user: @user)
    o.flagged_as_spam?.should == false
    # we now set the user, which would normally cause an item to be flagged
    # as spam by akismet. But since user isn't one of the text fields which
    # we send to akismet, and none of those fields were changed, the spam
    # check isn't triggered yet
    o.positional_accuracy = 1234
    o.save
    o.flagged_as_spam?.should == false
    o.reload
    # and now we set one of the configured fields and the spam check is
    # triggered. Since we set the spammy user above the check will fail
    # and create a spam flag
    o.description = "anything"
    o.save
    o.flagged_as_spam?.should == true
  end

  it "does not check for spam all fields are blank" do
    o = Observation.make!(user: @user)
    o.description = ""
    o.should_not_receive(:spam?)
    o.save
    o.flagged_as_spam?.should == false
  end

  it "creates a spam flag when the akismet check fails" do
    Rakismet.should_receive(:akismet_call).once.ordered.and_return("true")
    o = Observation.make!(user: @user)
    o.flagged_as_spam?.should == false
    o.description = "spam"
    o.save
    o.flagged_as_spam?.should == true
  end

  it "ultimately updates the users spam count" do
    starting_spam_count = @user.spam_count
    Rakismet.should_receive(:akismet_call).once.ordered.and_return("true")
    o = Observation.make!(user: @user, description: "something")
    @user.reload
    @user.spam_count.should == starting_spam_count + 1
  end

  it "knows which models are spammable" do
    Observation.spammable?.should == true
    Post.spammable?.should == true
    User.spammable?.should == true
    Photo.spammable?.should == false
    Site.spammable?.should == false
    Taxon.spammable?.should == false
  end

  it "identifies flagged content as known_spam?" do
    o = Observation.make!(user: @user)
    o.known_spam?.should == false
    Flag.make!(flaggable: o, flag: Flag::SPAM, user: @user)
    o.reload
    o.known_spam?.should == true
  end

  it "identifies spammer-owned content as owned_by_spammer?" do
    u = User.make!
    o = Observation.make!(user: u)
    o.owned_by_spammer?.should == false
    u.update_column(:spammer, true)
    o.reload
    o.owned_by_spammer?.should == true
  end

  it "users are spam if they are spammers" do
    u = User.make!
    u.owned_by_spammer?.should == false
    u.update_column(:spammer, true)
    u.reload
    u.owned_by_spammer?.should == true
  end

  it "all models respond to known_spam?" do
    Role.make!.known_spam?.should == false
    Taxon.make!.known_spam?.should == false
  end

  it "all models respond to spam_or_owned_by_spammer?" do
    Role.make!.owned_by_spammer?.should == false
    Taxon.make!.owned_by_spammer?.should == false
  end


  describe "User Exceptions" do
    it "does not check user life lists that have default values" do
      u = User.make!
      Rakismet.should_not_receive(:akismet_call)
      LifeList.make!(user: u, title: nil, description: nil)
    end

    it "gives users a dummy description if they dont have one specified" do
      User.make!(description: nil).instance_eval(
        &User.akismet_attrs[:comment_content]).should eq "New user"
    end

    it "knows when LifeLists have default values" do
      LifeList.make!(title: nil, description: nil).default_life_list?.
        should == true
      LifeList.make!(title: "Anything", description: nil).default_life_list?.
        should == false
    end

    it "will check Users for spam when various fields are modified" do
      u = User.make!
      u.flagged_as_spam?.should == false
      Rakismet.should_receive(:akismet_call).at_least(:once).and_return("true")
      # setting the place_id should not call Akismet
      u.place_id = Place.make!.id
      u.save
      u.flagged_as_spam?.should == false
      # reload was not resetting the instance variable @_spam
      u = User.find(u)
      # setting login, name, email, or description will call Akismet
      u.email = "anything@example.com"
      u.save
      u.flagged_as_spam?.should == true
    end
  end
end
