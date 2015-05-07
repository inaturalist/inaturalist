class Users::ConfirmationsController < Devise::ConfirmationsController
  before_filter :skip_mobile_format
  private
  def skip_mobile_format
    request.format = :html if request.format.mobile?
  end
end
