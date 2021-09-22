# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe DeviseMailer, "confirmation_instructions" do
  it "should default to English if no locale" do
    u = User.make!
    mail = DeviseMailer.confirmation_instructions(u, u.confirmation_token)
    expect( mail.body ).to include "activated"
  end

  it "should use the user's locale" do
    u = User.make!(:locale => "es-MX")
    mail = DeviseMailer.confirmation_instructions(u, u.confirmation_token)
    expect( mail.body ).to include I18n.t( :your_account_has_been_activated, locale: "es-MX" )
  end
end

describe DeviseMailer, "reset_password_instructions" do
  it "should have the right subject" do
    u = User.make!
    mail = DeviseMailer.reset_password_instructions(u, u.confirmation_token)
    expect( mail.subject ).to_not include "Welcome"
    expect( mail.subject ).to include "Reset"
  end

  it "should use the user's locale" do
    u = User.make!(:locale => "es-MX")
    mail = DeviseMailer.reset_password_instructions(u, u.confirmation_token)
    expect( mail.subject.downcase ).to_not include "reset"
    expect( mail.subject ).to include I18n.t(
      "devise.mailer.reset_password_instructions.subject", locale: "es-MX"
    )
  end

  it "should appear to come from the user's site" do
    site = Site.make!
    u = User.make!(site: site)
    mail = DeviseMailer.reset_password_instructions(u, u.confirmation_token)
    expect( mail.body ).to include site.url
  end
end
