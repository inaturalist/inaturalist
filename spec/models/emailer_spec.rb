# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Emailer, "updates_notification" do
  before do
    @observation = Observation.make!
    @comment = without_delay { Comment.make!(:parent => @observation) }
    @user = @observation.user
  end
  
  it "should work when recipient has a blank locale" do
    @user.update_attributes(:locale => "")
    @user.updates.all.should_not be_blank
    mail = Emailer.updates_notification(@user, @user.updates.all)
    mail.body.should_not be_blank
  end

  describe "with a site" do
    before do
      @site = Site.make!(:preferred_locale => "es-MX")
      @site.logo.stub!(:url).and_return("foo.png")
      @user.site = @site
      @user.save!
    end

    it "should use the user's site logo" do
      mail = Emailer.updates_notification(@user, @user.updates.all)
      mail.body.should match @site.logo.url
    end

    it "should use the user's site url as the base url" do
      mail = Emailer.updates_notification(@user, @user.updates.all)
      mail.body.should match @site.url
    end

    it "should default to the user's site locale if the user has no locale" do
      @user.update_attributes(:locale => "")
      mail = Emailer.updates_notification(@user, @user.updates.all)
      mail.body.should match /Nuevas actualizaciones/
    end

    it "should include site name in subject" do
      @user.update_attributes(:locale => "")
      mail = Emailer.updates_notification(@user, @user.updates.all)
      mail.subject.should match @site.name
    end
  end
end

describe Emailer, "new_message" do
  it "should work" do
    m = make_message
    mail = Emailer.new_message(m)
    mail.body.should_not be_blank
  end

  it "should not deliver flagged messages" do
    from_user = User.make!
    to_user = User.make!
    m = make_message(:from_user => from_user, :to_user => to_user, :user => from_user)
    m.send_message
    f = m.flags.create(:flag => "spam")
    m.reload
    mail = Emailer.new_message(m)
    mail.body.should be_blank
  end

  it "should not deliver if from_user is suspended" do
    m = make_message
    m.from_user.suspend!
    mail = Emailer.new_message(m)
    mail.body.should be_blank
  end
end

describe Emailer, "invite" do
  it "should work" do
    user = User.make!
    address = "foo@bar.com"
    params = {
      :sender_name => "Admiral Akbar",
      :personal_message => "it's a twap"
    }
    mail = Emailer.invite(address, params, user)
    mail.body.should_not be_blank
  end
end
