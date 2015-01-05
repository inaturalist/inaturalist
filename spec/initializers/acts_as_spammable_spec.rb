require File.expand_path("../../spec_helper", __FILE__)

describe "ActsAsSpammable" do

  before(:all) do
    Rakismet.disabled = false
    Rakismet.set_request_vars(
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_USER_AGENT" =>
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36"
    )
    @spam_user_name = "viagra-test-123"
    non_spam_user_name = "Uno who"
    @spam_user = User.make!(name: @spam_user_name)
    @non_spam_user = User.make!(name: non_spam_user_name)
  end

  after(:all) do
    Rakismet.disabled = true
  end

  it "recognizes spam" do
    o = Observation.make!(user: @spam_user)
    o.spam?.should == true
  end

  it "recognizes non-spam" do
    o = Observation.make!(user: @non_spam_user)
    o.spam?.should == false
  end

  it "knows when it has been flagged as spam" do
    o = Observation.make!(user: @non_spam_user)
    o.flagged_as_spam?.should == false
    Flag.make!(flaggable: o, flag: Flag::SPAM)
    o.flagged_as_spam?.should == true
  end

  it "does not check for spam unless a spammable field is modified" do
    o = Observation.make!
    o.flagged_as_spam?.should == false
    # we now set the user, which would normally cause an item to be flagged
    # as spam by akismet. But since user isn't one of the text fields which
    # we send to akismet, and none of those fields were changed, the spam
    # check isn't triggered yet
    o.user = @spam_user
    o.save
    o.flagged_as_spam?.should == false
    # and now we set one of the configured fields and the spam check is
    # triggered. Since we set the spammy user above the check will fail
    # and create a spam flag
    o.description = "anything"
    o.save
    o.flagged_as_spam?.should == true
  end

  it "creates a spam flag when the akismet check fails" do
    o = Observation.make!
    o.flagged_as_spam?.should == false
    o.user = @spam_user
    o.description = "spam"
    o.save
    o.flagged_as_spam?.should == true
  end

  it "ultimately updates the users spam count" do
    starting_spam_count = @spam_user.spam_count
    o = Observation.make!(user: @spam_user)
    o.description = "spam"
    o.save
    @spam_user.reload
    @spam_user.spam_count.should == starting_spam_count + 1
  end

end
