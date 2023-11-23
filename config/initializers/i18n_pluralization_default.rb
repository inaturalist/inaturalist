# frozen_string_literal: true

# By @nikosd at https://github.com/ruby-i18n/i18n/issues/123#issue-2208459
# This alters the default pluralization behavior so that the :one or :other
# plural keys are used if the desired plural key (e.g. :many) is missing.
# Particularly important for East Slavic languages where we're missing those
# plural keys in the translation files.
module I18n
  module Backend
    module Pluralization
      # Overriding the pluralization method so if the proper plural form is missing we will try
      # to fallback to the default gettext plural form (which is the `germanic` one).
      def pluralize( locale, entry, count )
        return entry unless entry.is_a?( Hash ) && count

        pluralizer = pluralizer( locale )
        if pluralizer.respond_to?( :call )
          # rubocop:disable Style/NumericPredicate
          return entry[:zero] if count == 0 && entry.key?( :zero )
          # rubocop:enable Style/NumericPredicate

          # Sometimes the pluralizer is going to get a string that's a number
          # with delimiters, so we need to parse that into an actual number
          count_num = if count.is_a?( String )
            count.to_s.
              gsub( I18n.t( "number.format.delimiter" ), "" ).
              gsub( I18n.t( "number.format.separator" ), "." ).
              to_f
          else
            count
          end

          plural_key = pluralizer.call( count_num )
          return entry[plural_key] if entry.key?( plural_key )

          # fallback to the default gettext plural forms if real entry is missing (for example :few)
          default_gettext_key = count == 1 ? :one : :other
          return entry[default_gettext_key] if entry.key?( default_gettext_key )

          # If nothing is found throw the classic exception
          raise InvalidPluralizationData.new( entry, count, plural_key )
        else
          super
        end
      end
    end
  end
end

# tell I18n to load custom pluralization config from config/locales/extra/plurals.rb
I18n.load_path.concat( [File.join( Rails.root, "config", "locales", "extra", "plurals.rb" )] )
