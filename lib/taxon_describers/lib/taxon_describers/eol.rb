module TaxonDescribers
  class Eol < Base
    def initialize( options = {} )
      super( options )
      @page_urls = {}
    end

    def describe(taxon)
      pages = eol_service.search(taxon.name, :exact => true)
      return if pages.blank?
      id = pages.at( "result/id" ).try(:content)
      return unless id
      page = eol_service.page( id, texts_per_page: 50, subjects: "all", details: true )
      return unless page
      @page_urls[taxon.id] = "https://eol.org/pages/#{id}"
      page.remove_namespaces!
      data_objects = data_objects_from_page(page).to_a.uniq do |data_object|
        data_object.at('subject').content
      end
      ApplicationController.render( partial: "/eol", locals: { data_objects: data_objects } )
    rescue Timeout::Error => e
      nil
    end

    def page_url( taxon )
      @page_urls[taxon.id] || "https://eol.org/search?q=#{taxon.name}"
    end

    def self.describer_name
      "EOL"
    end

    def data_objects_from_page(page, options = {})
      xpath = <<-XPATH
        //dataObject[
          descendant::dataType[text()='http://purl.org/dc/dcmitype/Text']
          and descendant::subject
        ]
      XPATH
      page.xpath(xpath).reject do |data_object|
        wrong_lang = data_object.at('language') && I18n.locale.to_s !~ /^#{data_object.at('language').content}/
        wrong_source = data_object.at_xpath("agent[@role='provider' and text()='Wikipedia']")
        wrong_lang || wrong_source
      end
    end

    protected
    def eol_service
      @eol_service ||= EolService.new(:timeout => 8)
    end
  end
end
