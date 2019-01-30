# Fix for `ThreadError: already initialized` errors when running
# controller specs with Ruby 2.6 and Rails 4.2.11
# See https://github.com/rails/rails/issues/34790
if RUBY_VERSION >= "2.6.0"
  if Rails.version < "5"
    class ActionController::TestResponse < ActionDispatch::TestResponse
      def recycle!
        # hack to avoid MonitorMixin double-initialize error:
        @mon_mutex_owner_object_id = nil
        @mon_mutex = nil
        initialize
      end
    end
  else
    puts "Monkeypatch for ActionController::TestResponse no longer needed"
  end
end
