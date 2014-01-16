module ListedTaxaHelper
  def display_list_title(list)
    if list.is_a?(CheckList) && list.is_default? && list.title.include?('Check List')
        list_title = truncate(t(:check_list_place, 
                                    :place => t("places_name.#{list.title.chomp(' Check List').gsub(' ','_').downcase}",
                                    :default => list.title.split(' Check List').first)), :length => 85) 
    else 
        list_title = truncate(list.title, :length => 85)
    end 
  end
end
