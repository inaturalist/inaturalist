class TranslationsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :locales]
  before_action :curator_required, except: [:index, :locales]

  def index
    redirect_to wiki_page_url( "translate" )
  end

  # Not sure why but without this Rails thinks this action isn't here, even
  # though it's defined in the superclass
  def translate
    # delete blank translations, or the translate gem will save them as empty
    # strings and fallbacks won't work
    params[:key].delete_if{|k,v| v.blank?}
    super
  end

  def locales
    render json: Hash[I18n.t(:locales).map{ |k,v| [k, I18n.t( "locales.#{k}", locale: k )] }]
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
