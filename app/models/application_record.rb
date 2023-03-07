# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Minimal string representation of the record that allows end users to
  # uniquely identify the record
  def to_plain_s
    "#{self.class.name} #{id}"
  end
end
