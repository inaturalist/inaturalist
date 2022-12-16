# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

describe DeviseMailer, "confirmation_instructions" do
  it "should default to English if no locale" do
    u = User.make!
    mail = DeviseMailer.confirmation_instructions( u, u.confirmation_token )
    expect( mail.subject ).to include I18n.t( "devise.mailer.confirmation_instructions.subject", locale: :en )
  end

  it "should use the user's locale" do
    u = User.make!( locale: "es-MX" )
    mail = DeviseMailer.confirmation_instructions( u, u.confirmation_token )
    expect( mail.subject ).to include I18n.t( "devise.mailer.confirmation_instructions.subject", locale: "es-MX" )
  end

  describe "with email suppressions" do
    let( :user ) { User.make! }

    before do
      expect( suppression.email ).to eq user.email
      allow( RestClient ).to receive( :delete )
      mail = DeviseMailer.confirmation_instructions( user, user.confirmation_token )
      expect( mail ).not_to be_blank
    end

    describe "for bounce" do
      let( :suppression ) do
        em = create :email_suppression, user: user, email: user.email, suppression_type: EmailSuppression::BOUNCES
        em
      end

      it "should delete the suppression" do
        expect( EmailSuppression.find_by_id( suppression.id ) ).to be_blank
      end

      it "should try delete to delete a bounce suppression on Sendgrid" do
        expect( RestClient ).to have_received( :delete )
      end
    end

    describe "for invalid_emails" do
      let( :suppression ) do
        em = create :email_suppression,
          user: user,
          email: user.email,
          suppression_type: EmailSuppression::INVALID_EMAILS
        em
      end

      it "should not delete the suppression" do
        expect( EmailSuppression.find_by_id( suppression.id ) ).not_to be_blank
      end

      it "should not try delete to delete a bounce suppression on Sendgrid" do
        expect( RestClient ).not_to have_received( :delete )
      end
    end
  end
end

describe DeviseMailer, "reset_password_instructions" do
  it "should have the right subject" do
    u = User.make!
    mail = DeviseMailer.reset_password_instructions( u, u.confirmation_token )
    expect( mail.subject ).to_not include "Welcome"
    expect( mail.subject ).to include "Reset"
  end

  it "should use the user's locale" do
    u = User.make!( locale: "es-MX" )
    mail = DeviseMailer.reset_password_instructions( u, u.confirmation_token )
    expect( mail.subject.downcase ).to_not include "reset"
    expect( mail.subject ).to include I18n.t(
      "devise.mailer.reset_password_instructions.subject", locale: "es-MX"
    )
  end

  it "should appear to come from the user's site" do
    site = Site.make!
    u = User.make!( site: site )
    mail = DeviseMailer.reset_password_instructions( u, u.confirmation_token )
    expect( mail.body ).to include site.url
  end
end
