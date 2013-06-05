require ::File.expand_path('../taxon_describers/base', __FILE__)
Dir[::File.expand_path('../taxon_describers/*.rb', __FILE__)].each {|f| require f}

module TaxonDescribers
  def self.describe(taxon, options = {})
    if options[:describer]
      txt = case options[:describer].to_s.downcase
      when "amphibiaweb" then TaxonDescribers::AmphibiaWeb.describe(taxon)
      when "eol" then TaxonDescribers::Eol.describe(taxon)
      when "conabio" then TaxonDescribers::Conabio.describe(taxon)
      end
      return txt
    end
    describers = options[:describers]
    describers = [Wikipedia, Eol] if describers.blank?
    describers.each do |describer|
      text = describer.describe(taxon)
      return text unless text.blank?
    end
  end

  def self.get_describer(name)
    return nil if name.blank?
    TaxonDescribers::Base.descendants.detect do |d|
      class_name = d.name.split('::').last
      class_name.downcase == name.downcase || class_name.underscore == name
    end
  end
end
