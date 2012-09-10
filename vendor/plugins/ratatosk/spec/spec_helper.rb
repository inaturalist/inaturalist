begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

# Load our custom matchers
Spec::Runner.configure do |config|
  config.include ClassMatchers
end

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

# inject a fixture check into CoL service wrapper.  Need to stop making HTTP requests in tests
class CatalogueOfLife
  def search(options = {})
    fname = "search_" + options.keys.sort_by(&:to_s).map{|k| "#{k}_#{options[k].gsub(/\W/, '_')}"}.flatten.join('_')
    fixture_path = File.expand_path(File.dirname(__FILE__) + "/fixtures/catalogue_of_life/#{fname}.xml")
    # puts "[DEBUG] fixture_path: #{fixture_path}"
    if File.exists?(fixture_path)
      Nokogiri::XML(open(fixture_path))
    else
      puts "[DEBUG] Couldn't find CoL response fixture, you should probably do this:\n wget -O #{fixture_path} \"#{CatalogueOfLife.url_for_request('search', options)}\""
      super(options)
    end
  end
end
