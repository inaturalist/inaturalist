# frozen_string_literal: true

require "spec_helper"

describe TranslationsController do
  describe "locales" do
    it "returns all locales translated into their respective languages" do
      get :locales, format: :json
      expect( response.response_code ).to eq 200
      locales = I18n.t(:locales)
      locales_response = JSON.parse( response.body )
      expect( locales.length ).to eq locales_response.length
      locales.each do |locale, string|
        expect( locales_response[locale.to_s] ).to eq I18n.t( "locales.#{locale}", locale: locale )
      end
    end
  end
end
