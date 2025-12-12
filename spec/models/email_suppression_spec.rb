# frozen_string_literal: true

require "spec_helper"

describe EmailSuppression do
  it { is_expected.to belong_to :user }

  describe "handle_sendgrid_webhook_event" do
    let( :user ) { create :user }

    before do
      allow( SendgridService ).to receive( :post_group_suppression )
      allow( SendgridService ).to receive( :delete_group_suppression )
    end

    describe "group_unsubscribe" do
      let( :event ) do
        {
          "email" => user.email,
          "timestamp" => Time.now.to_i,
          "smtp-id" => "<14c5d75ce93.dfd.64b469@ismtpd-555>",
          "event" => "group_unsubscribe",
          "category" => ["cat facts"],
          "sg_event_id" => "cJVmilvwcPPGCq9U4e7P_A==",
          "sg_message_id" => "14c5d75ce93.dfd.64b469.filter0001.16648.5515E0B88.0",
          "useragent" => "Mozilla/4.0 (compatible; MSIE 6.1; Windows XP; .NET CLR 1.1.4322; .NET CLR 2.0.50727)",
          "ip" => "255.255.255.255",
          "url" => "http://www.sendgrid.com/",
          "asm_group_id" => SendgridService.asm_group_ids[EmailSuppression::MESSAGES]
        }
      end

      it "creates an EmailSuppression" do
        expect do
          EmailSuppression.handle_sendgrid_webhook_event( event )
        end.to change( EmailSuppression, :count ).by( 1 )
      end

      it "creates an EmailSuppression with an email address" do
        expect( user.email_suppressions ).to be_blank
        EmailSuppression.handle_sendgrid_webhook_event( event )
        user.reload
        expect( user.email_suppressions.last.email ).to eq user.email
      end

      describe "for messages" do
        it "sets the user preference to false" do
          expect( event["asm_group_id"] ).to eq SendgridService.asm_group_ids[EmailSuppression::MESSAGES]
          expect( user.prefers_message_email_notification? ).to be true
          EmailSuppression.handle_sendgrid_webhook_event( event )
          user.reload
          expect( user.prefers_message_email_notification? ).to be false
        end
      end
    end

    describe "group_resubscribe" do
      let( :event ) do
        {
          "email" => user.email,
          "timestamp" => Time.now.to_i,
          "smtp-id" => "<14c5d75ce93.dfd.64b469@ismtpd-555>",
          "event" => "group_resubscribe",
          "category" => ["cat facts"],
          "sg_event_id" => "cJVmilvwcPPGCq9U4e7P_A==",
          "sg_message_id" => "14c5d75ce93.dfd.64b469.filter0001.16648.5515E0B88.0",
          "useragent" => "Mozilla/4.0 (compatible; MSIE 6.1; Windows XP; .NET CLR 1.1.4322; .NET CLR 2.0.50727)",
          "ip" => "255.255.255.255",
          "url" => "http://www.sendgrid.com/",
          "asm_group_id" => SendgridService.asm_group_ids[EmailSuppression::MESSAGES]
        }
      end

      it "deletes an existing EmailSuppression" do
        suppression = create :email_suppression, user: user, suppression_type: EmailSuppression::MESSAGES
        expect( event["asm_group_id"] ).to eq SendgridService.asm_group_ids[EmailSuppression::MESSAGES]
        EmailSuppression.handle_sendgrid_webhook_event( event )
        expect( EmailSuppression.find_by_id( suppression.id ) ).to be_nil
      end

      describe "for messages" do
        it "sets the user preference to true" do
          expect( event["asm_group_id"] ).to eq SendgridService.asm_group_ids[EmailSuppression::MESSAGES]
          user.update( prefers_message_email_notification: false )
          EmailSuppression.handle_sendgrid_webhook_event( event )
          user.reload
          expect( user.prefers_message_email_notification? ).to be true
        end
      end
    end
  end
end
