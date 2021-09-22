# Somewhere along the line, haml got dumber about wrapping attribute values that
# contain single quotes with double quotes. I think this fixes it...
Haml::Template.options[:attr_wrapper] = '"'
Haml::Template.options[:format] = :xhtml
