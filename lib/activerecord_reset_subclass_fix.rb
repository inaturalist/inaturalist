# lib/activerecord_reset_sublass_fix.rb
# https://gist.github.com/88826
# TODO remove in rails3
module ActiveRecord
  class Base
    def self.reset_subclasses #:nodoc:
      nonreloadables = []
      subclasses.each do |klass|
        unless ActiveSupport::Dependencies.autoloaded? klass
          nonreloadables << klass
          next
        end
      end
      @@subclasses = {}
      nonreloadables.each { |klass| (@@subclasses[klass.superclass] ||= []) << klass }
    end
  end
end
