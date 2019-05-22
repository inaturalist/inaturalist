# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe UserParent, "donorbox_donor_id" do
  it "should deliver an email when set" do
    up = UserParent.make!
    deliveries = ActionMailer::Base.deliveries.size
    up.update_attributes( donorbox_donor_id: 1 )
    expect( ActionMailer::Base.deliveries.size ).to eq deliveries + 1
  end
end
