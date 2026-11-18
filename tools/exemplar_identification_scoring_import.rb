# frozen_string_literal: true

require "rubygems"
require "optimist"
require "exemplar_identification_scoring_run"

OPTS = Optimist.options do
  banner <<~HELP
    Last Rails step of a scoring run. Imports
    exemplar_identification_scored.csv from the run directory into
    exemplar_identification_scores. The dropped, retried, failed and missing
    bodies are listed in exemplar_identification_import_rejects.csv in the
    run directory. With --log-task-name, a summary of the counts goes to the
    task log. Safe to rerun.

    Usage:

      rails runner tools/exemplar_identification_scoring_import.rb -d RUN_DIR

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
  counts = run.import
  summary = {
    step: "import",
    dir: OPTS.dir,
    started_at: started_at.utc.iso8601,
    duration_s: ( Time.now - started_at ).round
  }.merge( counts )
  task_logger&.info( summary.to_json )
  puts "Imported #{run.results_path} (#{summary[:duration_s]}s): " \
    "#{counts.map {| status, count | "#{status} #{count}" }.join( ', ' )}"
  puts "Rejects: #{run.import_rejects_path}"
rescue => e # rubocop:disable Style/RescueStandardError
  task_logger&.error( "#{e}\n#{e.backtrace[0..30].join( "\n" )}" )
  raise
ensure
  task_logger&.end
end
