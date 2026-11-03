# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Replace all iNat Ambassador designations with the contents of a CSV with
    the headers user_id,login,ambassador_since. Users not in the CSV lose
    their designation.
    Usage:
      rails runner tools/import_ambassadors.rb --file ambassadors.csv
    where [options] are:
  BANNER
  opt :file, "Path to the ambassadors CSV", type: :string, short: "-f", required: true
  opt :dry, "Dry run, don't actually change anything", type: :boolean
end

result = AmbassadorImporter.import( opts.file, dry: opts.dry )

puts "Imported #{result[:imported]} ambassadors#{' (dry run)' if opts.dry}"
puts "Unmatched rows (#{result[:unmatched].size}):"
result[:unmatched].each {| row | puts "  #{row}" }
puts "Rows with invalid dates (#{result[:invalid_dates].size}):"
result[:invalid_dates].each {| row | puts "  #{row}" }
