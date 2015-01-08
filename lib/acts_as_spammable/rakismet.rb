# added a disable attribute on the class which can be used to disable
# akismet API calls, for example when running specs which great tons
# of objects which would normally call the API in their after_save callback
module Rakismet
  class << self
    attr_accessor :disabled

    def spammable_models
      FlagsController::FLAG_MODELS.map(&:constantize).select{ |m| m.spammable? }
    end

    def fake_environment_variables
      {
        "REMOTE_ADDR" => "127.0.0.1",
        "HTTP_USER_AGENT" =>
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36"
      }
    end
  end
end
