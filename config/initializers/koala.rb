if File.exists?("/etc/ssl/certs")
  Koala.http_service.http_options = { :ssl => { :ca_path => "/etc/ssl/certs" } }
end
