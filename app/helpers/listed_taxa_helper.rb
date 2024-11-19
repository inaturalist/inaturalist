# frozen_string_literal: true

module ListedTaxaHelper
  def display_list_title( list, trunc = 85 )
    if list.is_a?( CheckList ) && list.is_default? && list.title.include?( "Check List" )
      place_name = list.place&.translated_name || ""
      truncate(
        t( :check_list_place, place: place_name, default: list.title.split( " Check List" ).first ),
        length: trunc
      )
    elsif list
      truncate( list.title, length: trunc )
    else
      t( :unknown )
    end
  end
end
