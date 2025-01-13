# frozen_string_literal: true

# Base class for DarwinCore Extension adapters. The class describes the
# extension and provides methods for making data and metadata to include in
# the archive.

module DarwinCore
  module Extensions
    # Abstract extension with stubs for required class methods
    class Base
      def self.filename
        raise "#{name} has not implemented filename"
      end

      def self.descriptor
        raise "#{name} has not implemented descriptor"
      end

      def self.make_file
        raise "#{name} has not implemented make_file"
      end

      def self.data( _options = {} )
        raise "#{name} has not implemented data"
      end
    end

    # Abstract extension for extenions that adapt observations with stubs for
    # required class methods
    class ObservationExtension < Base
      def self.observations_to_csv( _observations, _csv, _options = {} )
        raise "#{name} has not implemented observations_to_csv"
      end
    end
  end
end
