module Shared::FiltersModule
  private

  def set_request_locale
    # use params[:locale] for single-request locale settings,
    # otherwise use the session, user's preferred, or site default,
    # or application default locale
    locale = params[:locale]
    locale = current_user.try(:locale) if locale.blank?
    locale = session[:locale] if locale.blank?
    locale = @site.locale if @site && locale.blank?
    locale = locale_from_header if locale.blank?
    locale = I18n.default_locale if locale.blank?
    if locale =~ /\-[a-z]/
      pieces = locale.split( "-" )
      locale = "#{pieces[0].downcase}-#{pieces[1].upcase}"
    end
    I18n.locale = locale
    if I18n.locale.to_s == "iw"
      I18n.locale = I18n.locale.to_s.sub( "iw", "he" ).to_sym
    end
    unless I18N_SUPPORTED_LOCALES.include?( I18n.locale.to_s )
      I18n.locale = I18n.default_locale
    end
    true
  end

  def locale_from_header
    return if request.env["HTTP_ACCEPT_LANGUAGE"].blank?
    http_locale = request.env["HTTP_ACCEPT_LANGUAGE"].
      split(/[;,]/).select{ |l| l =~ /^[a-z-]+$/i }.first
    return if http_locale.blank?
    lang, region = http_locale.split( "-" ).map(&:downcase)
    return lang if region.blank?
    # These re-mappings will cause problem if these regions ever get
    # translated, so be warned. Showing zh-TW for people in Hong Kong is
    # *probably* fine, but Brazilian Portuguese for people in Portugal might
    # be a bigger problem.
    if lang == "es" && region == "xl"
      region = "mx"
    elsif lang == "zh" && region == "hk"
      region = "tw"
    elsif lang == "pt" && region == "pt"
      region = "br"
    end
    locale = "#{lang.downcase}-#{region.upcase}"
    if I18N_SUPPORTED_LOCALES.include?( locale )
      locale
    elsif I18N_SUPPORTED_LOCALES.include?( lang )
      lang
    end
  end

  def set_site
    if params[:inat_site_id]
      @site ||= Site.find_by_id( params[:inat_site_id] )
    end
    @site ||= Site.where( "url LIKE '%#{request.host}%'" ).first
    @site ||= Site.default
    @site
  end
end
