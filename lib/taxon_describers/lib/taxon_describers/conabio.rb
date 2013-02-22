require ::File.expand_path('../eol', __FILE__)
module TaxonDescribers
  class Conabio < Eol
    def data_objects_from_page(page, options = {})
      xpath = <<-XPATH
        //dataObject[
          descendant::dataType[text()='http://purl.org/dc/dcmitype/Text']
          and descendant::subject
          and descendant::agent[@role='provider' and text()='Conabio']
        ]
      XPATH
      page.xpath(xpath)
    end

    def self.describer_name
      "CONABIO"
    end
  end
end