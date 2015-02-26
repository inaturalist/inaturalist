class TranslationsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :curator_required

  # Not sure why but without this Rails thinks this action isn't here, even
  # though it's defined in the superclass
  def translate
    # delete blank translations, or the translate gem will save them as empty
    # strings and fallbacks won't work
    params[:key].delete_if{|k,v| v.blank?}
    super
  end

  private
  def curator_required
    unless user_signed_in? && current_user.is_curator?
      flash[:notice] = "Only curators can access that page."
      redirect_to root_url
      return false
    end
  end
end
