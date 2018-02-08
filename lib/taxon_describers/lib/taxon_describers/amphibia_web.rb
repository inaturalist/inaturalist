module TaxonDescribers
  class AmphibiaWeb < Base
    def describe(taxon)
      names = [taxon.taxon_names.select{|n| n.is_scientific?}.map(&:name), taxon.name].flatten.uniq
      xml = nil
      while xml.blank? && !names.blank?
        xml, genus_name, species_name = data_for_name(names.pop)
      end
      return nil if xml.blank?
      fake_view.render("amphibia_web", :doc => xml, :genus_name => genus_name, :species_name => species_name)
    end

    def data_for_name(name)
      genus_name, species_name = name.split
      url = "https://amphibiaweb.org/cgi/amphib_ws?where-genus=#{genus_name}&where-species=#{species_name}&src=eol"
      xml = Nokogiri::XML(open(url))
      return nil if xml.blank? || xml.children.blank? || xml.at('error')
      [xml, genus_name, species_name]
    end

    def page_url(taxon)
      genus_name, species_name = taxon.name.split
      "https://amphibiaweb.org/cgi-bin/amphib_query?where-scientific_name=#{genus_name}+#{species_name}"
    end
  end
end
