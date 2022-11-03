# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

# This spec does something rspec isn't really designed to do: it tests data and
# not code. So... it involves a lot of weird stuff like testing to see if a test
# will fail before running the test. If we actually run real rspec tests on all
# translation strings, this will take forever. If there's a better way to get
# these tests to run in Travis, please holler

# Adapted from tools/i18qa.rb

def traverse( obj, key = nil, &blk )
  case obj
  when Hash
    # Kind of a lame hack to detect situations when translatewiki has translated
    # an array as a hash with numbered keys. They generally don't translate
    # position 0, so if the first key is a number greater than zero, we assume
    # it's one of those arrays here.
    if obj.keys.first.to_s.to_i > 0
      blk.call( obj, key )
    else
      obj.each {| k, v | traverse( v, [key, k].compact.join( "." ), &blk ) }
    end
  else
    blk.call( obj, key )
  end
end

describe "translations" do
  # Sometimes Crowdin seems to set the root of pt-BR to pt, which makes
  # all the pt-BR translations unavailable to everyone with that
  # preference
  it "locales should have a root key that matches the locale" do
    Dir.glob( "config/locales/*.yml" ).each do | path |
      next if path =~ /qqq.yml/

      locale = File.basename( path, ".yml" )
      yaml = YAML.load_file( path )
      unless locale =~ /(phonetic|doorkeeper)/
        expect( yaml.keys.first ).to eq locale
      end
    end
  end

  it "locales should pass a series of tests" do
    en_translations = {}
    traverse( YAML.load_file( "config/locales/en.yml" ) ) do | translation, key |
      en_translations[key] = translation
    end
    Dir.glob( "config/locales/*.yml" ).each do | path |
      next if path =~ /qqq.yml/

      locale = File.basename( path, ".yml" )
      next if locale == "en"

      separator_values = {}
      traverse( YAML.load_file( path ) ) do | translation, key |
        en_key = key.sub( "#{locale}.", "en." )
        if key =~ /^#{locale}\.i18n\.inflections\.gender\./
          # it "should be a blank gender inflection"
          expect( key ).not_to eq( "#{locale}.i18n.inflections.gender." ),
            "#{key}: gender inflection cannot be blank"
        end
        next unless en_translations[en_key]

        if en_translations[en_key].is_a?( Array )
          # For some reason, translatewiki tends to translate yaml arrays as yaml
          # hashes with numbered keys. Our arrays often begin with a blank for
          # position 0, and translatewiki tends not to include that in their hash, so
          # ignore that in the count
          # it "should have all members of an array"
          expect( en_translations[en_key].size ).to eq( translation.size ),
            "#{key}: should have all members of an array"
          next
        elsif !en_translations[en_key].is_a?( String )
          next
        end

        variables = translation.scan( /%{.+?}/ )
        variables.each do | variable |
          # Bit of a kludge, but a lot of our singular form translations look like
          # "1 observation" in the source string when they should probably look
          # like "%{count} observation". The localization libs handle the %{count}
          # variable regardless, so this is not really a problem worth raising
          # alarms about
          # rubocop:disable Style/FormatStringToken
          next if en_key =~ /\.one/ && variable == "%{count}"
          # rubocop:enable Style/FormatStringToken

          next if en_translations[en_key] =~ /#{variable.encode( "utf-8" )}/

          # it "#{variable} should be present in the source string"
          expect( en_translations[en_key] ).to match( /#{variable.encode( "utf-8" )}/ ),
            "#{key}: #{variable} should be present in source string: \"#{en_translations[en_key]}\""
        end

        # https://stackoverflow.com/a/3314572
        if translation =~ %r{</?\s+[^\s]+>}
          # it "should not have HTML with leading spaces"
          expect( translation ).not_to match( %r{</?\s+[^\s]+>} ),
            "#{key}: \"#{translation}\" should not have HTML with leading spaces"
        end

        complete_inflections_pattern = /@\w+\{[^@{]+?\}/
        started_inflections_pattern = /@\w+\{/
        if translation.scan( complete_inflections_pattern ).size != translation.scan( started_inflections_pattern ).size
          # it "should not have unclosed inflections"
          expect(
            translation.scan( complete_inflections_pattern ).size
          ).to eq( translation.scan( started_inflections_pattern ).size ),
            "#{key} should not have unclosed inflections"
        end

        # keep track of `separator` keys to compare them to `delimiter` keys on a second pass
        if key.split( "." ).last == "separator"
          separator_values[key] = translation
        end
      end

      traverse( YAML.load_file( path ) ) do | translation, key |
        en_key = key.sub( "#{locale}.", "en." )
        next unless en_translations[en_key]
        next unless en_translations[en_key].is_a?( String )

        if key.split( "." ).last == "delimiter"
          sep_key = key.sub( "delimiter", "separator" )
          if ( sep = separator_values[sep_key] )
            # it "#{key} should not be the same as #{sep_key}"
            expect( sep ).not_to eq( translation ), "#{key} should not have the same as #{sep_key}"
          end
        end
      end
    end
  end
end
