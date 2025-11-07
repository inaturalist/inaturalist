# frozen_string_literal: true

class IdSummariesDemoController < ApplicationController
  before_action :require_id_summaries_demo_access

  def index
    render layout: "basic"
  end

  private

  def require_id_summaries_demo_access
    allowed_ids = Array.wrap( CONFIG.id_summaries_demo&.allowed_user_ids ).map( &:to_i ).reject( &:zero? )
    return admin_required if allowed_ids.blank?
    return true if logged_in? && current_user.is_admin?
    return true if logged_in? && allowed_ids.include?( current_user.id )

    message = t( :you_dont_have_permission_to_do_that )
    respond_to do |format|
      format.html do
        flash[:error] = message
        redirect_back_or_default( root_url )
      end
      format.json { render status: :forbidden, json: { error: message } }
      format.js { render status: :forbidden, plain: message }
    end
    throw :abort
  end
end
