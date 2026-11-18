# frozen_string_literal: true

require "rubygems"
require "optimist"
require "exemplar_identification_score_backfill"

OPTS = Optimist.options do
  banner <<~HELP
    One-time backfill of exemplar_identification_scores. Imports the initial
    run (July 2026) from exemplar_identification_backfill.csv, gives
    every other exemplar identification a row, then resets bodies edited
    during the backfill, reconciles the active flag and deletes orphan rows.
    The July lines not imported as they are, and the rows reset, are listed
    in exemplar_identification_backfill_rejects.csv next to the file, and the
    counts are logged with --log-task-name. Safe to rerun: existing rows are
    never overwritten.

    Usage:

      rails runner tools/exemplar_identification_score_backfill.rb -f FILE

    where [options] are:
  HELP
  opt :file, "Path to exemplar_identification_backfill.csv", type: :string, short: "-f", required: true
  opt :started_at, "When the first attempt started, when rerunning it (e.g. \"2026-11-20 10:00:00 UTC\")",
    type: :string
  opt :log_task_name, "Log with the specified task name", type: :string
end

if OPTS.log_task_name
  task_logger = TaskLogger.new( OPTS.log_task_name, nil, "sync" )
end

def step( summary, name )
  start = Time.now
  result = yield
  duration = ( Time.now - start ).round
  summary[name] = { duration_s: duration, result: result }
  puts "#{name} (#{duration}s): #{result}"
  result
end

begin
  task_logger&.start
  started_at = OPTS.started_at ? Time.parse( OPTS.started_at ) : Time.now
  backfill = ExemplarIdentificationScoreBackfill.new( OPTS.file, started_at: started_at )
  summary = { step: "backfill", file: OPTS.file, started_at: backfill.started_at.utc.iso8601 }
  puts "Started at #{backfill.started_at.utc} (pass it as --started-at to rerun)"
  step( summary, :import ) { backfill.import }
  step( summary, :fill_gaps ) { backfill.fill_gaps }
  step( summary, :reset_edited ) { backfill.reset_edited }
  step( summary, :reconcile_active ) { backfill.reconcile_active }
  step( summary, :delete_orphans ) { backfill.delete_orphans }
  step( summary, :status_counts ) { backfill.status_counts }
  check = step( summary, :row_check ) { backfill.row_check }
  task_logger&.info( summary.to_json )
  puts "Rejects: #{backfill.rejects_path}"
  unless check[:difference].zero?
    puts "WARNING: exemplars and rows differ, rerun with --started-at #{backfill.started_at.utc.iso8601}"
  end
rescue => e # rubocop:disable Style/RescueStandardError
  task_logger&.error( "#{e}\n#{e.backtrace[0..30].join( "\n" )}" )
  raise
ensure
  task_logger&.end
end
