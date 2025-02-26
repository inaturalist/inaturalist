# frozen_string_literal: true

require ::File.expand_path( "extensions/base", __dir__ )
Dir[::File.expand_path( "extensions/*.rb", __dir__ )].each {| f | require f }

module DarwinCore
  module Extensions
  end
end
