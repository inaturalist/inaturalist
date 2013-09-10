# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe DeviseMailer, "confirmation_instructions" do
  it "should default to English if no locale" do
    u = User.make!
    mail = DeviseMailer.confirmation_instructions(u)
    mail.body.should =~ /Welcome/
  end

  it "should use the user's locale" do
    u = User.make!(:locale => "es-MX")
    mail = DeviseMailer.confirmation_instructions(u)
    mail.body.should =~ /Bienvenido/
  end
end
