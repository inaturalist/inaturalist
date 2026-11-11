# frozen_string_literal: true

require "csv"

module AmbassadorImporter
  class InvalidCSV < StandardError; end

  HEADERS = %w(user_id login ambassador_since).freeze

  def self.import( path, dry: false )
    rows = CSV.read( path, headers: true, header_converters: ->( h ) { h.strip.downcase } )
    missing = HEADERS - rows.headers
    raise InvalidCSV, "Missing headers: #{missing.join( ', ' )}" if missing.any?

    result = { imported: 0, unmatched: [], invalid_dates: [] }
    User.transaction do
      User.where.not( ambassador_since: nil ).update_all( ambassador_since: nil )
      rows.each do | row |
        user = User.find_by( id: row["user_id"].to_i ) || User.find_by( login: row["login"]&.strip )
        next result[:unmatched] << row.to_h unless user

        since = parse_date( row["ambassador_since"] )
        next result[:invalid_dates] << row.to_h unless since

        user.update_column( :ambassador_since, since )
        result[:imported] += 1
      end
      raise InvalidCSV, "No rows could be imported" if result[:imported].zero?
      raise ActiveRecord::Rollback if dry
    end
    result
  end

  def self.parse_date( value )
    Date.parse( value.to_s )
  rescue Date::Error
    nil
  end
end
