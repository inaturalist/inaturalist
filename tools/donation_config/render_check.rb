# frozen_string_literal: true

# Renders amounts with ActiveSupport the way the app will, from the fields
# parse.js produces. Reads a JSON array of { "fields": {...}, "code": "EUR",
# "amounts": [5, 1000] } on stdin and prints a JSON array of arrays of strings.
#
#   bundle exec ruby tools/donation_config/render_check.rb < cases.json

require "logger"
require "json"
require "active_support"
require "active_support/number_helper"

# Lakh/crore grouping: 10,00,000
INDIAN_DELIMITER_PATTERN = /(\d+?)(?=(\d\d)+(\d)(?!\d))/

def render( fields, code, amount )
  options = {
    unit: fields["symbol"],
    format: fields["format"].gsub( "%c", code.to_s ),
    precision: 0,
    delimiter: fields["delimiter"],
    separator: fields["separator"] || "."
  }
  if fields["group_min_digits"].to_i == 2 && amount.to_i.abs.to_s.length < 5
    options[:delimiter] = ""
  end
  options[:delimiter_pattern] = INDIAN_DELIMITER_PATTERN if fields["grouping"] == "indian"
  ActiveSupport::NumberHelper.number_to_currency( amount, options )
end

cases = JSON.parse( $stdin.read )
puts JSON.generate( cases.map {| c | c["amounts"].map {| a | render( c["fields"], c["code"], a ) } } )
