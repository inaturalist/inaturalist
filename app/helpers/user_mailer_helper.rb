module UserMailerHelper
  def show_field_prefix(field)
    case field
    when 'species_not_found'
      "The species listed below were not found in the #{CONFIG.site_name} database."
    end
  end

  def show_field_suffix(field)
    case field
    when 'species_not_found'
      "<p>Please check the spelling for each entry. If your spelling is correct, please search on the species at #{CONFIG.site_url}#{search_taxa_path}. If the name is not yet in the #{CONFIG.site_name} names system, you'll need to add it before your bulk upload will work. The instructions for adding a new species to #{CONFIG.site_name} are in the \"Not Seeing What You're Looking For?\" section on the species search results page.</p>
      <p>If your file contains lots of correct names that are not yet in #{CONFIG.site_name}, this method will quickly get tedious (this could happen especially for marine invertebrate species). Please contact #{CONFIG.help_email} with your species list and we'll get them loaded onto the system.</p>
      <p>If you fix up those issues, your spreadsheet should upload fine. Please let us know at #{CONFIG.help_email} if you have trouble.</p>".html_safe
    end
  end
end
