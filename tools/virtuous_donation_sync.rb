# frozen_string_literal: true

require "rubygems"
require "optimist"
require "virtuous_service"

opts = Optimist.options do
  banner <<~BANNER
    Sync Virtuous donations

    Usage:

      rails runner tools/virtuous_donation_sync.rb

    where [options] are:
  BANNER
  opt :dry, "Dry run, don't actually change anything", type: :boolean
  opt :debug, "Output additional debug logging", type: :boolean
  opt :after_date, "Sync donations modified after this date/time", type: :string
  opt :log_task_name, "Log with the specified task name", type: :string
end

if !CONFIG.virtuous || !CONFIG.virtuous.token
  raise "Virtuous token hasn't been added to config"
end

if opts.log_task_name
  task_logger = TaskLogger.new( opts.log_task_name, nil, "sync" )
end

begin
  task_logger&.start
  options = {
    after_date: opts.after_date,
    debug: opts.debug,
    dry_run: opts.dry
  }
  virtuous_service = VirtuousService.new( options )
  virtuous_service.fetch_donors
rescue => e # rubocop:disable Style/RescueStandardError
  task_logger&.error( "#{e}\n#{e.backtrace[0..30].join( "\n" )}" )
  raise
ensure
  task_logger&.end
end
