# frozen_string_literal: true

# Override of the Devise class to localize error responses based on HTTP headers
class InatDeviseFailureApp < Devise::FailureApp
  def i18n_options( options )
    options.merge( locale: normalize_locale( request_accept_language ) )
  end

  def request_accept_language
    if request.respond_to?( :headers ) && request.headers.respond_to?( :[] )
      return request.headers["Accept-Language"]
    end

    if request.respond_to? :get_header
      return request.get_header( "Accept-Language" )
    end

    request.env["Accept-Language"]
  end
end
