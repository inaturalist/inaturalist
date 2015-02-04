# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe DeviseMailer, "confirmation_instructions" do
  it "should default to English if no locale" do
    u = User.make!
    mail = DeviseMailer.confirmation_instructions(u, u.confirmation_token)
    mail.body.should =~ /Welcome/
  end

  it "should use the user's locale" do
    u = User.make!(:locale => "es-MX")
    mail = DeviseMailer.confirmation_instructions(u, u.confirmation_token)
    mail.body.should =~ /Bienvenido/
  end
end

describe DeviseMailer, "reset_password_instructions" do
  it "should have the right subject" do
    u = User.make!
    mail = DeviseMailer.reset_password_instructions(u, u.confirmation_token)
    mail.subject.should_not =~ /Welcome/
    mail.subject.should =~ /Reset/
  end

  it "should use the user's locale" do
    u = User.make!(:locale => "es-MX")
    mail = DeviseMailer.reset_password_instructions(u, u.confirmation_token)
    mail.subject.downcase.should_not =~ /reset/
  end
end
