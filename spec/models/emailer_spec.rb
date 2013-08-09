# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Emailer, "updates_notification" do
  it "should work when recipient has a blank locale" do
    t = Taxon.make!
    tn = TaxonName.make!(:taxon => t)
    i = without_delay { Identification.make!(:taxon => t) }
    u = i.observation.user
    u.update_attributes(:locale => "")
    u.updates.all.should_not be_blank
    mail = Emailer.updates_notification(u, u.updates.all)
    mail.body.should_not be_blank
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
