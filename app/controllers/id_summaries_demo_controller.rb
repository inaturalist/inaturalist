# frozen_string_literal: true

class IdSummariesDemoController < ApplicationController
  before_action :restrict_admin_mode

  def index
    render layout: "basic"
  end

  private

  def restrict_admin_mode
    return true unless params[:admin_mode].present?
    return true if logged_in? && current_user.is_admin?

    message = t( :you_dont_have_permission_to_do_that )
    respond_to do |format|
      format.html do
        flash[:error] = message
        redirect_back_or_default( root_url )
      end
      format.json { render status: :forbidden, json: { error: message } }
      format.js { render status: :forbidden, plain: message }
    end
    false
  end
end
