class LogstasherCatchAllErrors
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue Exception => exception
      Logstasher.write_exception(exception)
      raise exception
    end
  end
end
