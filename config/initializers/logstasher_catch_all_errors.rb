class LogstasherCatchAllErrors
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue Exception => exception
      user = env['warden'] ? env['warden'].user : nil
      Logstasher.write_exception(exception, user: user, session: env['rack.session'])
      raise exception
    end
  end
end
Rails.application.config.middleware.insert_before ActionDispatch::DebugExceptions, LogstasherCatchAllErrors
