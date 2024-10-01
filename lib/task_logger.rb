# frozen_string_literal: true

require "json"
require "time"

class TaskLogger
  # Initialize logger with default parameters
  def initialize( task, identifier, type, subtype )
    @task = task
    @identifier = identifier || default_identifier( task )
    @type = type
    @subtype = subtype
    @start_time = nil
    @log_file = File.join( CONFIG.task_logger_output, "#{task}.log" )
  end

  # Start method, sets the start time
  def start
    @start_time = ( Time.now.utc.to_f * 1000 ).to_i # Save current time in milliseconds
    log( "started" )
  end

  # Info log method
  def info( message = "" )
    log( "info", message )
  end

  # Error log method
  def error( message = "" )
    log( "error", message )
  end

  # End method, calculate duration and log completion
  def end
    log( "finished" )
  end

  private

  # Helper to generate a default identifier based on task name and current date
  def default_identifier( task )
    Time.now.strftime( "#{task}_%Y.%m.%d_%H.%M.%S%z" )
  end

  # Helper to generate a log entry
  def log( status, message = "" )
    timestamp = Time.now.utc.iso8601( 3 ) # Generate ISO 8601 timestamp with milliseconds

    # Calculate duration only if the status is 'finished' and start time is set
    duration = if @start_time && status == "finished"
      ( ( Time.now.to_f * 1000 ).to_i - @start_time )
    else
      0
    end

    # Create the log entry as a hash
    log_entry = {
      task: @task,
      identifier: @identifier,
      task_type: @type,
      task_subtype: @subtype,
      status: status,
      log_message: message,
      duration: duration,
      timestamp: timestamp
    }

    # Convert log entry to JSON and append to the log file
    File.open( @log_file, "a" ) do | file |
      file.write( "#{log_entry.to_json}\n" )
    end
  end
end
