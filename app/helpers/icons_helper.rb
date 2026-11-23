# frozen_string_literal: true

module IconsHelper
  def icon_svg( name )
    File.read( Rails.root.join( "app/assets/images/icons/#{name}.svg" ) ).strip.html_safe
  end
end
