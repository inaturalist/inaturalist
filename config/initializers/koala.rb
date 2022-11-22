if File.exists?("/etc/ssl/certs")
  if Koala.http_service.respond_to?("http_options=")
    Koala.http_service.http_options = { :ssl => { :ca_path => "/etc/ssl/certs" } }
  elsif Koala.http_service.respond_to?("ca_path=")
    Koala.http_service.ca_path = "/etc/ssl/certs"
  end
elsif File.exists?("/usr/local/share/ca-bundle.crt")
  (Koala.http_service.http_options[:ssl] ||= {})[:ca_file] = '/usr/local/share/ca-bundle.crt'
end

Koala.config.api_version = "v10.0"
