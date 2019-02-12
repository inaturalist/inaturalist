module Shared::FiltersModule
  private

  def set_request_locale
    # use params[:locale] for single-request locale settings,
    # otherwise use the session, user's preferred, or site default,
    # or application default locale
    locale = params[:locale]
    locale = session[:locale] if locale.blank?
    locale = current_user.try(:locale) if locale.blank?
    locale = @site.locale if @site && locale.blank?
    locale = locale_from_header if locale.blank?
    locale = I18n.default_locale if locale.blank?
    I18n.locale = locale
    if I18n.locale.to_s == "he"
      I18n.locale = I18n.locale.to_s.sub( "he", "iw" ).to_sym
    end
    unless I18N_SUPPORTED_LOCALES.include?( I18n.locale.to_s )
      I18n.locale = I18n.default_locale
    end
    true
  end

  def set_site
    if params[:inat_site_id]
      @site ||= Site.find( params[:inat_site_id] )
    end
    @site ||= Site.where( "url LIKE '%#{request.host}%'" ).first
    @site ||= Site.default
  end
end
