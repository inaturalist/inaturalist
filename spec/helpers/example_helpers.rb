# http://tech.thereq.com/post/13437077944/unit-testing-your-rails-3-1-caching-with-rspec
module ExampleHelpers
  module CachingTestHelpers
    module ResponseHelper
      def action_cached?
        request.path.action_cached?
      end

      def page_cached?
        request.path.page_cached?
      end

      def private_page_cached?
        request.path.private_page_cached?
      end
    end
    ActionDispatch::TestResponse.send(:include, ResponseHelper)
  end
end
 
class String
  def action_cached?
    Rails.cache.exist?("views/www.example.com#{self}")
  end

  def private_page_cached?
    File.exists? private_page_cache_path(self)
  end
end
 
 
RSpec.configure do |config|
  config.include ExampleHelpers::CachingTestHelpers, :type => :request
end
