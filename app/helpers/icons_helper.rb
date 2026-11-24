# frozen_string_literal: true

module IconsHelper
  ICON_SVGS = Concurrent::Map.new

  def icon_svg( name )
    ICON_SVGS.compute_if_absent( name ) do
      File.read( Rails.root.join( "app/assets/images/icons/#{name}.svg" ) ).strip.html_safe
    end
  end
end
