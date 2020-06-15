module Shared::MailerModule
  def self.included( base )
    base.after_action :set_sendgrid_headers
  end

  private
  def set_sendgrid_headers
    mailer = self.class.name
    headers "X-SMTPAPI" => {
      category:    [ mailer, "#{mailer}##{action_name}" ],
      unique_args: { environment: Rails.env },
      asm_group_id: CONFIG.sendgrid && CONFIG.sendgrid.asm_group_ids ? CONFIG.sendgrid.asm_group_ids.default : nil
    }.to_json
  end
end
