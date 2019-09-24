require 'forwardable'

# This class was extracted from Observation. Isn't thread-safe as it temporary
# changes global time zone configuration during parsing.
# Leverages Forwardable to access observation's fields easily.
module Observations
  class ParseObservedOnString
    extend Forwardable
    def_delegators :observation,
      :observed_on_string,
      :observed_on_string_changed?,
      :time_zone,
      :time_zone_changed?,
      :time_zone_was,
      :user

    def initialize(observation)
      @observation = observation
      @old_time_zone = Time.zone
    end

    def call
      if observed_on_string.blank?
        observation.observed_on = nil
        observation.time_observed_at = nil
        return true
      end
      # Only re-interpret the date if observed_on_string or time_zone changed
      return unless observed_on_string_changed? || time_zone_changed?

      build_working_date_string
      parsed_time_zone = remove_time_zone_from_working_string
      set_time_zone(parsed_time_zone) if observed_on_string_changed?
      strip_and_convert_working_date_string

      begin
        setup_working_time_zone
        set_timestamps_with_chronic
        handle_relative_observed_on_strings
      ensure
        restore_time_zone_settings
      end

      true
    end

    private

    attr_reader :observation, :date_string, :old_time_zone

    def build_working_date_string
      @date_string = observed_on_string.strip

      if date_string =~ /#{tz_js_offset_pattern} #{tz_failed_abbrev_pattern}/
        @date_string = date_string.sub(tz_failed_abbrev_pattern, '').strip
      end
    end

    def remove_time_zone_from_working_string
      tz_abbrev = date_string[tz_abbrev_pattern, 1]

      # Rails timezone support doesn't seem to recognize this abbreviation, and
      # frankly I have no idea where ActiveSupport::TimeZone::CODES comes from.
      # In case that ever stops working or a less hackish solution is required,
      # check out https://gist.github.com/kueda/3e6f77f64f792b4f119f
      tz_abbrev = 'CET' if tz_abbrev == 'CEST'

      parsed_time_zone = ActiveSupport::TimeZone::CODES[tz_abbrev]
      if parsed_time_zone
        @date_string = observed_on_string.sub(tz_abbrev_pattern, '')
        @date_string = date_string.sub(tz_js_offset_pattern, '').strip
        # If the parsed time zone is one of the ambiguous ones where we can't
        # really know which one they're referring too, don't actually use the zone
        # code we parsed out of the string
        parsed_time_zone = nil if problematic_tz?(tz_abbrev)
      elsif (offset = date_string[tz_offset_pattern, 1]) &&
          (n = offset.to_f / 100) &&
          (key = n == 0 ? 0 : n.floor + (n%n.floor)/0.6) &&
          (parsed_time_zone = ActiveSupport::TimeZone[key])
        @date_string = date_string.sub(tz_offset_pattern, '')
      elsif (offset = date_string[tz_js_offset_pattern, 2]) &&
          (n = offset.to_f / 100) &&
          (key = n == 0 ? 0 : n.floor + (n%n.floor)/0.6) &&
          (parsed_time_zone = ActiveSupport::TimeZone[key])
        @date_string = date_string.sub(tz_js_offset_pattern, '')
        @date_string = date_string.sub(/^(Sun|Mon|Tue|Wed|Thu|Fri|Sat)\s+/i, '')
      elsif ( offset = date_string[tz_colon_offset_pattern, 2] ) &&
          ( t = Time.parse(offset ) ) &&
          ( negpos = offset.to_i > 0 ? 1 : -1 ) &&
          ( parsed_time_zone = ActiveSupport::TimeZone[negpos * t.hour+t.min/60.0] )
        @date_string = date_string.sub(/#{tz_colon_offset_pattern}|#{tz_failed_abbrev_pattern}/, '')
      elsif ( offset = date_string[tz_moment_offset_pattern, 1] ) &&
          ( parsed_time_zone = ActiveSupport::TimeZone[offset.to_i] )
        @date_string = date_string.sub( tz_moment_offset_pattern, "" )
      end
      parsed_time_zone
    end

    def set_time_zone(parsed_time_zone)
      return unless parsed_time_zone

      observation.time_zone = parsed_time_zone.name
      begin
        if (
          ( user_time_zone = ActiveSupport::TimeZone[user.time_zone] ) &&
          user_time_zone != parsed_time_zone &&
          user_time_zone.utc_offset == parsed_time_zone.utc_offset
        )
          observation.time_zone = user.time_zone
        end
      rescue ArgumentError => e
        raise e unless e.message =~ /offset/ || e.message =~ /invalid argument to TimeZone/
        # This means the user didn't have a time zone or had a time zone that
        # shouldn't exist, so just ignore it
      end
    end

    def strip_and_convert_working_date_string
      date_string.sub!('T', ' ') if date_string =~ /\d{4}-\d{2}-\d{2}T/
      date_string.sub!(/(\d{2}:\d{2}:\d{2})\.\d+/, '\\1')

      # strip leading month if present
      date_string.sub!(/^[A-z]{3} ([A-z]{3})/, '\\1')

      # strip paranthesized stuff
      date_string.gsub!(/\(.*\)/, '')

      # strip noon hour madness
      # this is due to a weird, weird bug in Chronic
      if date_string =~ /p\.?m\.?/i
        date_string.gsub!( /( 12:(\d\d)(:\d\d)?)\s+?p\.?m\.?/i, '\\1')
      elsif date_string =~ /a\.?m\.?/i
        date_string.gsub!( /( 12:(\d\d)(:\d\d)?)\s+?a\.?m\.?/i, '\\1')
        date_string.gsub!( / 12:/, " 00:" )
      end
    end

    # Abbreviations with synonyms at https://en.wikipedia.org/wiki/List_of_time_zone_abbreviations
    def problematic_tz?(tz)
      %w(
        AST
        BRT
        BST
        CDT
        CST
        ECT
        GST
        IST
        PST
      ).include?(tz)
    end

    def setup_working_time_zone
      begin
        Time.zone = time_zone || user.try(:time_zone)
      rescue ArgumentError
        # Usually this would happen b/c of an invalid time zone being specified
        observation.time_zone = time_zone_was || old_time_zone.name
      end
      Chronic.time_class = Time.zone
    end

    def restore_time_zone_settings
      Time.zone = old_time_zone
    end

    # don't store relative observed_on_strings, or they will change
    # every time you save an observation!
    def handle_relative_observed_on_strings
      if date_string =~ /today|yesterday|ago|last|this|now|monday|tuesday|wednesday|thursday|friday|saturday|sunday/i
        observation.observed_on_string = observation.observed_on.to_s
        if observation.time_observed_at
          observation.observed_on_string = observation.time_observed_at.strftime("%Y-%m-%d %H:%M:%S")
        end
      end
    end

    def set_timestamps_with_chronic
      t = begin
        Chronic.parse( date_string, context: :past )
      rescue ArgumentError
        nil
      end
      t = Chronic.parse( date_string.split[0..-2].join(' '), context: :past ) unless t
      if !t && (locale = user.locale || I18n.locale)
        @date_string = englishize_month_abbrevs_for_locale(date_string, locale)
        t = Chronic.parse( date_string, context: :past )
      end

      if !t
        I18N_SUPPORTED_LOCALES.each do |locale|
          next if locale =~ /^en.*/
          new_date_string = englishize_month_abbrevs_for_locale(date_string, locale)
          break if t = Chronic.parse( new_date_string, context: :past )
        end
      end
      return true unless t

      # Re-interpret future dates as being in the past
      t = Chronic.parse( date_string, context: :past) if t > Time.now

      observation.observed_on = t.to_date if t

      # try to determine if the user specified a time by ask Chronic to return
      # a time range. Time ranges less than a day probably specified a time.
      if tspan = Chronic.parse( date_string, context: :past, guess: false )
        # If tspan is less than a day and the string wasn't 'today', set time
        if tspan.width < 86400 && date_string.strip.downcase != 'today'
          observation.time_observed_at = t
        else
          observation.time_observed_at = nil
        end
      end
    rescue RuntimeError, ArgumentError
      # ignore these, just don't set the date
      return true
    end

    def tz_abbrev_pattern
      /\s\(?([A-Z]{3,})\)?$/ # ends with (PDT)
    end

    def tz_offset_pattern
      /([+-]\d{4})$/ # contains -0800
    end

    def tz_js_offset_pattern
      /(GMT)?([+-]\d{4})/ # contains GMT-0800
    end

    def tz_colon_offset_pattern
      /(GMT|HSP)([+-]\d+:\d+)/ # contains (GMT-08:00)
    end

    def tz_moment_offset_pattern
      /\s([+-]\d{2})$/ # contains -08, +05, etc.
    end

    def tz_failed_abbrev_pattern
      /\(#{tz_colon_offset_pattern}\)/
    end

    def englishize_month_abbrevs_for_locale(date_string, locale)
      # HACK attempt to translate month abbreviations into English.
      # A much better approach would be add Spanish and any other supported
      # locales to https://github.com/olojac/chronic-l10n and switch to the
      # 'localized' branch of Chronic, which seems to clear our test suite.
      return date_string if locale.to_s =~ /^en/
      return date_string unless I18N_SUPPORTED_LOCALES.include?(locale)
      I18n.t('date.abbr_month_names', :locale => :en).each_with_index do |en_month_name,i|
        next if i == 0
        localized_month_name = I18n.t('date.abbr_month_names', :locale => locale)[i]
        next if localized_month_name == en_month_name
        date_string.gsub!(/#{localized_month_name}([\s\,])/, "#{en_month_name}\\1")
      end
      date_string
    end
  end
end
