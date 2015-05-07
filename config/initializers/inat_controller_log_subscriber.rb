# monkey patch controller logging to include URL and timing in the same line
module ActionController
  class LogSubscriber
    def process_action(event)
      payload   = event.payload
      additions = ActionController::Base.log_process_action(payload)
      status = payload[:status]
      if status.nil? && payload[:exception].present?
        exception_class_name = payload[:exception].first
        status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
      end
      message = "Completed #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]} #{payload[:method]} #{payload[:path].gsub("%","%%")} in %.0fms" % event.duration
      message << " (#{additions.join(" | ")})" unless additions.blank?
      info(message)
    end
  end
end