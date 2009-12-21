if config.respond_to?(:gems)
  config.gem 'objectify-xml', :version => '>=0.2.3', :lib => 'objectify_xml'
else
  begin
    require 'objectify_xml'
  rescue LoadError
    begin
      gem 'objectify-xml', '>=0.2.3'
    rescue Gem::LoadError
      puts "Install the objectify-xml gem to enable piscasa support"
    end
  end
end

config.to_prepare do
  require "ruby_picasa"
end