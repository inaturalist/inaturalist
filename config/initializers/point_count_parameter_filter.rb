# frozen_string_literal: true

# The private pilot submits coordinates and potentially location-bearing remarks.
# Keep its entire form payload out of Rails request logs; SQL logging is privileged.
Rails.application.config.filter_parameters += [:point_count]
