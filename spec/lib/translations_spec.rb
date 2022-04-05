# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

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
      obj.each {|k,v| traverse( v, [key, k].compact.join( "." ), &blk ) }
    end
  else
    blk.call( obj, key )
  end
end

describe "translations" do
  data = {}
  Dir.glob( "config/locales/*.yml" ).each do |path|
    next if path =~ /qqq.yml/
    locale = File.basename( path, ".yml" )
    yaml = YAML.load_file( path )
    unless locale =~ /(phonetic|doorkeeper)/
      # Sometimes Crowdin seems to set the root of pt-BR to pt, which makes
      # all the pt-BR translations unavailable to everyone with that
      # preference
      it "#{locale} should have a root key that matches the locale" do
        expect( yaml.keys.first ).to eq locale
      end
    end
    traverse( YAML.load_file( path ) ) do |translation, key|
      data[key] = translation
    end
  end

  data.each do |key, translation|
    next if key =~ /^en\./
    locale = key[/^(.+?)\./, 1]
    en_key = key.sub( "#{locale}.", "en." )
    describe key do
      if key =~ /^#{locale}\.i18n\.inflections\.gender\./
        it "should be a blank gender inflection" do
          expect( key ).not_to eq "#{locale}.i18n.inflections.gender."
        end
      end
      next unless data[en_key]
      if data[en_key].is_a?( Array )
        # For some reason, translatewiki tends to translate yaml arrays as yaml
        # hashes with numbered keys. Our arrays often begin with a blank for
        # position 0, and translatewiki tends not to include that in their hash, so
        # ignore that in the count
        it "should have all members of an array" do
          expect( data[en_key].size ).to eq translation.size
        end
        next
      elsif !data[en_key].is_a?( String )
        next
      end
      variables = translation.scan( /%{.+?}/ )
      variables.each do |variable|
        # Bit of a kludge, but a lot of our singular form translations look like
        # "1 observation" in the source string when they should probably look
        # like "%{count} observation". The localization libs handle the %{count}
        # variable regardless, so this is not really a problem worth raising
        # alarms about
        next if en_key =~ /\.one/ && variable == "%{count}"
        unless data[en_key] =~ /#{variable.encode( "utf-8" )}/
          it "#{variable} should be present in the source string" do
            expect( data[en_key] ).to match /#{variable.encode( "utf-8" )}/
          end
        end
      end

      # https://stackoverflow.com/a/3314572
      if translation =~ /<\/?\s+[^\s]+>/
        it "should not have HTML with leading spaces" do
          expect( translation ).not_to match /<\/?\s+[^\s]+>/
        end
      end

      complete_inflections_pattern = /@\w+\{[^@\{]+?\}/
      started_inflections_pattern = /@\w+\{/
      if translation.scan( complete_inflections_pattern ).size != translation.scan( started_inflections_pattern ).size
        it "should not have unclosed inflections" do
          expect( translation.scan( complete_inflections_pattern ).size ).to eq translation.scan( started_inflections_pattern ).size
        end
      end

      if key.split( "." ).last === "delimiter"
        sep_key = key.sub( "delimiter", "separator" )
        if sep = data[sep_key]
          it "#{key} should not be the same as #{sep_key}" do
            expect( sep ).not_to eq translation
          end
        end
      end
    end
  end
end
