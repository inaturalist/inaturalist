# frozen_string_literal: true

# Turns a Flipper flag on for everyone, so e2e specs can reach pages gated behind it.
#
#   app( "enable_feature_flag", { key: "blog_v2" } )
Flipper.enable( command_options["key"] )
[command_options["key"]]
