# frozen_string_literal: true

module Shared
  module FiltersModule
    private

    def set_request_locale
      # use params[:locale] for single-request locale settings,
      # otherwise use the session, user's preferred, or site default,
      # or application default locale
      locale = params[:locale]
      locale = current_user.try( :locale ) if locale.blank?
      locale = session[:locale] if locale.blank?
      locale = @site.locale if @site && locale.blank?
      locale = locale_from_header if locale.blank?
      locale = I18n.default_locale if locale.blank?
      I18n.locale = normalize_locale( locale )
      @rtl = params[:test] == "rtl" || current_user&.in_test_group?( "rtl" )
      true
    end

    def locale_from_header
      return if request.env["HTTP_ACCEPT_LANGUAGE"].blank?

      http_locale = request.env["HTTP_ACCEPT_LANGUAGE"].
        split( /[;,]/ ).grep( /^[a-z-]+$/i ).first
      return if http_locale.blank?

      lang, region = http_locale.split( "-" ).map( &:downcase )
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
end
