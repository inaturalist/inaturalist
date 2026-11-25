# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

# Characterizes how account-critical email handles SendGrid suppressions today
# (WEB-1478). EmailSuppression.destroy_for_email only acts on rows in the local
# email_suppressions mirror, which tools/sync_sendgrid_suppressions.rb refreshes
# weekly. WEB-1513 replaces this behavior, and should update these examples.
describe "Account-critical email and SendGrid suppressions" do
  let( :user ) { User.make! }

  before do
    # The test config has no `account` ASM group. destroy_remote also needs an
    # api_key, or it returns before calling SendGrid.
    allow( CONFIG ).to receive( :sendgrid ).and_return( double(
      api_key: "test-key",
      primary_ip_pool: nil,
      asm_group_ids: double( default: 1, account: 2 )
    ) )
    allow( RestClient ).to receive( :delete )
  end

  def smtpapi( mail )
    JSON.parse( mail.header["X-SMTPAPI"].value )
  end

  describe DeviseMailer, "reset_password_instructions" do
    # Mailer methods are lazy, so each example forces the build with .message
    # or by reading headers.
    context "when the unsubscribe is on SendGrid but not yet in the local mirror" do
      # TODO: WEB-1513 should deliver this email anyway by sending it with
      # bypass_list_management. Still expect no DELETE.
      it "does not delete anything on SendGrid, so SendGrid drops the email" do
        expect( EmailSuppression.where( email: user.email ) ).to be_empty
        DeviseMailer.reset_password_instructions( user, "token" ).message
        expect( RestClient ).not_to have_received( :delete )
      end
    end

    context "when the local mirror has the global unsubscribe" do
      before do
        create :email_suppression, user: user, email: user.email,
          suppression_type: EmailSuppression::UNSUBSCRIBES
      end

      # TODO: WEB-1513 should keep the user's opt-out. Expect no DELETE, and
      # expect the local row to remain.
      it "deletes the user's global unsubscribe on SendGrid" do
        DeviseMailer.reset_password_instructions( user, "token" ).message
        expect( RestClient ).to have_received( :delete ).with(
          "https://api.sendgrid.com/v3/asm/suppressions/global/#{user.email}", anything
        )
        expect( EmailSuppression.where( email: user.email ) ).to be_empty
      end
    end

    # TODO: WEB-1513 should send no ASM group, bypass_list_management on and
    # subscriptiontrack off.
    it "sends the account ASM group and no bypass filter" do
      headers = smtpapi( DeviseMailer.reset_password_instructions( user, "token" ) )
      expect( headers["asm_group_id"] ).to eq 2
      expect( headers["filters"] ).to be_nil
    end

    # TODO: WEB-1513 should not render the unsubscribe link in account-critical
    # email.
    it "renders the group unsubscribe link" do
      mail = DeviseMailer.reset_password_instructions( user, "token" )
      expect( mail.body.to_s ).to include "{{asm_group_unsubscribe_raw_url}}"
    end
  end

  describe Emailer, "user_suspended" do
    it "does not delete anything on SendGrid when the mirror has no suppression" do
      Emailer.user_suspended( user, "hate_speech", nil ).deliver_now
      expect( RestClient ).not_to have_received( :delete )
    end

    # TODO: WEB-1513 should turn bypass_list_management on and subscriptiontrack
    # off, so the notice reaches unsubscribed users.
    it "sends no ASM group and no bypass filter" do
      headers = smtpapi( Emailer.user_suspended( user, "hate_speech", nil ) )
      expect( headers ).not_to have_key( "asm_group_id" )
      expect( headers["filters"] ).to be_nil
    end
  end
end
