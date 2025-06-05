# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

describe PicasaPhoto do
  it { is_expected.to validate_presence_of :native_photo_id }
end
