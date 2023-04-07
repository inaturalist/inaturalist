# frozen_string_literal: true

module HasGuideAsset
  extend ActiveSupport::Concern

  def asset_filename( options = {} )
    size = options[:size].to_s
    size = "original" unless %w(thumb small medium original).include?( size )
    ext = send( "#{size}_url" ).to_s[%r{.+\.([A-z]+)[^/]*?$}, 1]
    fname = "#{self.class.name.underscore}-#{id}-#{size}"
    fname = "#{fname}.#{ext}" unless ext.blank?
    fname
  end
end
