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
