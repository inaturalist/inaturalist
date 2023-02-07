# frozen_string_literal: true

module Users
  module CustomDeviseModule
    extend ActiveSupport::Concern

    included do
      include Shared::FiltersModule

      # You have to use prepend, plus there are no fallbacks for some reason, so
      # if we're setting the locale to en-US from the headers, en-US.yml *must*
      # have the relevant translations, otherwise it will render the defaults
      # from the Devise gem, *not* our translations in en.yml
      prepend_before_action :set_request_locale

      # This needs to happen before setting the locale... which means it needs
      # to be prepended after it. Ugh.
      prepend_before_action :set_site

      before_action :load_registration_form_data, only: [:new, :create]
      layout "registrations"
    end
  end
end
