# Disable digests in cache keys by default, b/c they just make them harder to expire
# http://stackoverflow.com/a/25839145/720268
module ActionView
  module Helpers
    module CacheHelper
      def cache_fragment_name(name = {}, options = nil)
        skip_digest = options && !options[:skip_digest].nil? ? options[:skip_digest] : true
        if skip_digest
          name
        else
          fragment_name_with_digest(name)
        end
      end
    end
  end
end

# added March 2020 in response to an ActionView vulnerability
# see https://github.com/advisories/GHSA-65cv-r6x7-79hv for more info
ActionView::Helpers::JavaScriptHelper::JS_ESCAPE_MAP.merge!(
  {
    "`" => "\\`",
    "$" => "\\$"
  }
)

module ActionView::Helpers::JavaScriptHelper
  alias :old_ej :escape_javascript
  alias :old_j :j

  def escape_javascript(javascript)
    javascript = javascript.to_s
    if javascript.empty?
      result = ""
    else
      result = javascript.gsub(/(\\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"']|[`]|[$])/u, JS_ESCAPE_MAP)
    end
    javascript.html_safe? ? result.html_safe : result
  end

  alias :j :escape_javascript
end
