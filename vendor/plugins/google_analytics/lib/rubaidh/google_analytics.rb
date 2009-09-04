module Rubaidh # :nodoc:
  module GoogleAnalyticsMixin
    def google_analytics_code(request = nil)
      return unless GoogleAnalytics.enabled?
      GoogleAnalytics.google_analytics_code(request)
    end
    
    # An after_filter to automatically add the analytics code.
    def add_google_analytics_code
      code = google_analytics_code(request)
      return if code.blank?
      response.body.gsub! '</body>', code + '</body>' if response.body.respond_to?(:gsub!)
    end
  end

  class GoogleAnalytics
    # Specify the Google Analytics ID for this web site.  This can be found
    # as the value of +_uacct+ in the Javascript excerpt
    @@tracker_id = nil
    cattr_accessor :tracker_id

    # Specify a different domain name from the default.  You'll want to use
    # this if you have several subdomains that you want to combine into
    # one report.  See the Google Analytics documentation for more
    # information.
    @@domain_name = nil
    cattr_accessor :domain_name
    
    # I can't see why you'd want to do this, but you can always change the
    # analytics URL.
    @@analytics_url = 'http://www.google-analytics.com/urchin.js'
    cattr_accessor :analytics_url

    # I can't see why you'd want to do this, but you can always change the
    # analytics URL (ssl version).
    @@analytics_ssl_url = 'https://ssl.google-analytics.com/urchin.js'
    cattr_accessor :analytics_ssl_url

    # The environments in which to enable the Google Analytics code.  Defaults
    # to 'production' only.
    @@environments = ['production']
    cattr_accessor :environments

    # Return true if the Google Analytics system is enabled and configured
    # correctly.
    def self.enabled?
      (environments.include?(RAILS_ENV) and
        not tracker_id.blank? and
        not analytics_url.blank?)
    end
    
    def self.google_analytics_code(request = nil)
      extra_code = domain_name.blank? ? nil : "_udn = \"#{domain_name}\";"
      url = (not request.blank? and request.ssl?) ? analytics_ssl_url : analytics_url

      # OK, I'm not very bright -- I tried to turn this into a partial and
      # failed miserably!  So it'll have to live here for now.
      code = <<-HTML
      <script src="#{url}" type="text/javascript">
      </script>
      <script type="text/javascript">
      _uacct = "#{tracker_id}";
      #{extra_code}
      urchinTracker();
      </script>
      HTML
      code
    end
  end
end