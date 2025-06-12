# frozen_string_literal: true

class WebhooksController < ApplicationController
  before_action :doorkeeper_authorize!,
    only: [:sendgrid],
    if: -> { authenticate_with_oauth? }

  def sendgrid
    # Only staff can declare an app to be "official," i.e. owned and managed
    # by staff. Any other client
    unless doorkeeper_token.application.official?
      respond_to do | format |
        format.any { head :forbidden }
      end
      return false
    end

    params[:_json]&.each {| event | EmailSuppression.handle_sendgrid_webhook_event( event ) }
    respond_to do | format |
      format.any { head :no_content }
    end
  end
end
