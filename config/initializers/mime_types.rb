# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register_alias "text/html", :iphone
Mime::Type.register "application/vnd.google-earth.kml+xml", :kml
Mime::Type.register "text/xml", :dwc
Mime::Type.register "text/json", :node
Mime::Type.register "text/json", :geojson
Mime::Type.register_alias "text/javascript", :widget, %w( application/javascript application/x-javascript )
Mime::Type.register_alias "text/html", :mobile
