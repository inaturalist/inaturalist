# frozen_string_literal: true

require "rubygems"
require "optimist"
require "exemplar_identification_scoring_run"

OPTS = Optimist.options do
  banner <<~HELP
    First Rails step of a scoring run. Sets the rows of a run that died back
    to pending, then exports the exemplar identification bodies waiting to be
    scored to exemplar_identification_to_score.csv in the run directory.
    Recovered and short bodies are listed in
    exemplar_identification_export_rejects.csv, and the counts are logged
    with --log-task-name.

    Usage:

      rails runner tools/exemplar_identification_scoring_export.rb -d RUN_DIR

    where [options] are:
  HELP
  opt :dir, "Run directory", type: :string, short: "-d", required: true
  opt :log_task_name, "Log with the specified task name", type: :string
end

if OPTS.log_task_name
  task_logger = TaskLogger.new( OPTS.log_task_name, nil, "sync" )
end

begin
  task_logger&.start
  started_at = Time.now
  run = ExemplarIdentificationScoringRun.new( OPTS.dir )
  recovered = run.recover
  counts = run.export
  summary = {
    step: "export",
    dir: OPTS.dir,
    started_at: started_at.utc.iso8601,
    duration_s: ( Time.now - started_at ).round,
    recovered: recovered
  }.merge( counts )
  task_logger&.info( summary.to_json )
  puts "Recovered #{recovered} rows from a previous run"
  puts "Marked #{counts[:marked]}, written #{counts[:written]}, skipped as short #{counts[:skipped_short]} " \
    "-> #{run.to_score_path} (#{summary[:duration_s]}s)"
  puts "Rejects: #{run.export_rejects_path}"
rescue => e # rubocop:disable Style/RescueStandardError
  task_logger&.error( "#{e}\n#{e.backtrace[0..30].join( "\n" )}" )
  raise
ensure
  task_logger&.end
end
