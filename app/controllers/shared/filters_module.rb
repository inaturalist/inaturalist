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
      locale = normalize_locale( request.env["HTTP_ACCEPT_LANGUAGE"] ) if locale.blank?
      locale = I18n.default_locale if locale.blank?
      # Remove calendar stuff
      locale = locale.to_s.sub( /@.*/, "" )
      if locale =~ /-[a-z]/
        pieces = locale.split( "-" )
        locale = "#{pieces[0].downcase}-#{pieces[1].upcase}"
      end
      I18n.locale = locale
      # Handle outdated locale code for Hebrew
      if I18n.locale.to_s == "iw"
        I18n.locale = I18n.locale.to_s.sub( "iw", "he" ).to_sym
      end
      if I18n.locale.to_s.starts_with?( "zh-" )
        # Map script subtags for Chinese to relevant Crowdin locales
        if I18n.locale.to_s.include?( "Hans" )
          I18n.locale = "zh-CN"
        elsif I18n.locale.to_s.include?( "Hant-HK" )
          I18n.locale = "zh-HK"
        elsif I18n.locale.to_s.include?( "Hant" )
          I18n.locale = "zh-TW"
        end
      end
      # Fall back to language code if language-region combo isn't supported
      unless I18N_SUPPORTED_LOCALES.include?( I18n.locale.to_s )
        I18n.locale = I18n.locale.to_s.split( "-" ).first
      end
      # Set to default if locale isn't supported
      unless I18N_SUPPORTED_LOCALES.include?( I18n.locale.to_s )
        I18n.locale = I18n.default_locale
      end
      @rtl = params[:test] == "rtl" && ["ar", "fa", "he"].include?( I18n.locale.to_s )
      true
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
