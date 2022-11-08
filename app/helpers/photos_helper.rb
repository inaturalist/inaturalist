# frozen_string_literal: true

module PhotosHelper
  REJECTED_TAGS = ( ExifMetadata::REJECTED_TAGS + %i[dc dimensions] ).freeze

  def metadata_table_rows(photo )
    return unless photo.metadata.present?

    metadata = visible_metadata photo: photo, with_coords: coords_visible?( photo )
    transform_metadata( metadata ).each do | k, v |
      concat( content_tag( :tr ) { content_tag( :th, k ) + content_tag( :td, v, class: "ui" ) } )
    end
  end

  private

  def transform_metadata( metadata )
    metadata.map do | k, v |
      new_key = k.to_s.humanize.gsub /Gps/, "GPS"
      new_val = if k.to_s =~ /gps/i
        v.is_a?( EXIFR::TIFF::Degrees ) || v.is_a?( Rational ) ? v.to_f : v
      else
        case v
        when EXIFR::TIFF::Orientation then v.to_i
        when String then formatted_user_text( v.utf_safe )
        else v
        end
      end
      [new_key, new_val]
    end.to_h
  end

  def visible_metadata( photo:, with_coords: )
    return photo.metadata.select { _1.to_s =~ /copyright/i } unless logged_in?

    photo.metadata.dup.tap do | md |
      md.except!( *REJECTED_TAGS )
      md.reject! { _1.to_s =~ /description/i }
      md.reject! { _1.to_s =~ /(gps|date)/i } unless with_coords
    end
  end

  def coords_visible?( photo )
    photo.observations.detect {| o | !o.coordinates_viewable_by?( current_user ) }.blank?
  end
end
