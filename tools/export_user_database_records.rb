# frozen_string_literal: true

require "rubygems"
require "optimist"
require "csv"

OPTS = Optimist.options do
  banner <<~HELP
    Export some user data from the database, often to be used in conjunction with
    tools/export_user_logs.rb. These are select database records we may be
    legally required to provide given formal official request.

    BE CAREFUL. This exports personal information and the results are NOT
    for general dissemination. Only share with staff.

    Usage:

      rails runner tools/export_user_database_records.rb -u USER_ID --start-date YYYY-MM-DD --end-date YYYY-MM-DD

    where [options] are:
  HELP
  opt :user_id, "ID of target user", type: :integer, short: "-u"
  opt :start_date, "Export data created ", type: :string
  opt :end_date, "end-date", type: :string
end

unless OPTS.user_id
  puts "You must specify a user_id"
  exit( 0 )
end

USER = User.find_by_id( OPTS.user_id )
unless USER
  puts "User `#{OPTS.user_id}` does not exist"
  exit( 0 )
end

START_DATE = Date.parse( OPTS.start_date )
unless START_DATE
  puts "You must specify a valid start date"
  exit( 0 )
end

END_DATE = Date.parse( OPTS.end_date )
unless END_DATE
  puts "You must specify a valid end date"
  exit( 0 )
end

puts "Exporting logs for #{USER.id} / #{USER.login} from #{START_DATE} until #{END_DATE}"

WORK_PATH = Dir.mktmpdir
FileUtils.mkdir_p( WORK_PATH, mode: 0o755 )
FILE_SUFFIX = "#{Date.today.to_s.gsub( '-', '' )}-#{Time.now.to_i}".freeze

def export_messages
  export_columns = [
    :id,
    :user_id,
    :from_user_id,
    :to_user_id,
    :thread_id,
    :subject,
    :body,
    :read_at,
    :created_at,
    :updated_at
  ]
  CSV.open( File.join( WORK_PATH, "export-user-#{USER.id}-messages-postgresql-" + FILE_SUFFIX ), "w" ) do | csv |
    csv << export_columns
    messages = Message.where(
      "created_at >= ? AND created_at <= ?", START_DATE, END_DATE
    ).where(
      "from_user_id = ? OR to_user_id = ?", USER.id, USER.id
    ).select( export_columns ).order( :created_at )
    next if messages.empty?

    messages.each do | message |
      csv << export_columns.map {| c | message.send( c ) }
    end
  end
end

export_messages

puts "\n\nRecords exported to #{WORK_PATH}"
puts "\nPlease move the data in #{WORK_PATH} to a secure location then delete the directory\n\n\n"
