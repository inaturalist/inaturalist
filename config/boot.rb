# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path( "../Gemfile", __dir__ )

require "bundler/setup" # Set up gems listed in the Gemfile.
# require 'bootsnap/setup' # Speed up boot time by caching expensive operations.
require "rack/mobile-detect"
# requiring logger so we can install concurrent-ruby > 1.3.5 while on Rails 6.x
require "logger"
