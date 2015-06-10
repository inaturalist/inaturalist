class CustomLogFormatter < Logger::Formatter
  def call(severity, time, program_name, message)
    "[#{ time.to_formatted_s(:db) }] (PID: #{$$}) #{ message }\n"
  end
end
