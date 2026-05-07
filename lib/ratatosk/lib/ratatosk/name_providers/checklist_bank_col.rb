module Ratatosk
  module NameProviders

    #
    # Concrete strategy for getting names from ChecklistBank - Catalogue of Life
    #
    class ChecklistBankNameProvider
      cattr_accessor :source

      PRIMARY_DATASET_ID  = 3 # COL core release
      FALLBACK_DATASET_ID = 314396 # COL extended release

      API_BASE = 'https://api.checklistbank.org/dataset'.freeze

      def self.source
        citation = <<-EOT
          Bánki, O., Roskov, Y., Döring, M., Ower, G., Hernández Robles, D. R., Plata Corredor, C. A., Stjernegaard Jeppesen, T., Örn, A., Pape, T., Hobern, D., Garnett, S., Little, H., DeWalt, R. E., Miller, J., Orrell, T., Aalbu, R., Abbott, J., Abreu, C., Acero P, A., et al. (2026). Catalogue of Life (2026-04-18 XR). Catalogue of Life Foundation, Amsterdam, Netherlands. https://doi.org/10.48580/dgxjw
          Catalogue of Life ChecklistBank API. Accessed via https://api.checklistbank.org/.
        EOT

        @source ||= ::Source.find_by_title("Catalogue of Life ChecklistBank") ||
          ::Source.create(
            :title     => "Catalogue of Life ChecklistBank",
            :in_text   => "Bánki et al., 2026",
            :url       => "https://api.checklistbank.org/",
            :citation  => citation.gsub(/[\s\n]+/m, ' ')
          )
      end

      def initialize
        @service = ChecklistBank.new(10)
      end

      def normalize_scientific_name(name)
        name.to_s
            .downcase
            .strip
            .gsub(/\s+/, ' ')
      end
     
      STATUS_PRIORITY = {
        'accepted' => 0,
        'provisionally accepted' => 1,
        'synonym' => 2
        }.freeze
        
      def rank_priority(rank, query)
        rank = rank.to_s.downcase
        
        if species_query?(query)
            {
            'species' => 0,
            'subspecies' => 1,
            'variety' => 2,
            'form' => 3,
            }.fetch(rank, 999)
        else
            { # TODO: add more ranks
            'genus' => 0,
            'subgenus' => 1,
            'subfamily' => 2,
            'family' => 3,
            'order' => 4,
            'class' => 5,
            'phylum' => 6,
            'kingdom' => 7,
            }.fetch(rank, 999)
        end
      end

      def normalized_query_parts(query)
        normalize_scientific_name(query).split(/\s+/).first(2)
      end

      def canonical_query(query)
        normalized_query_parts(query).join(' ')
      end

      def species_query?(query)
        normalized_query_parts(query).length >= 2
      end

      def exact_match_results(results, query)
        normalized_query = canonical_query(query)
        
        results.select do |result|
          scientific_name =
            result.dig('usage', 'name', 'scientificName')
            
          canonical_query(scientific_name) == normalized_query
        end
      end

      def best_exact_match(results, query)
        exact = exact_match_results(results, query)
        
        exact.sort_by do |result|
            usage = result['usage'] || {}
            name  = usage['name'] || {}
        
            [
            STATUS_PRIORITY.fetch(
                usage['status'],
                999
            ),
            rank_priority(
                name['rank'],
                999
              )
            ]
        end.first
      end
      #
      # Find matching name.
      #
      def find(name)
        response = @service.search(name)

        if response.nil?
          raise NameProviderError,
            "ChecklistBank returned an empty response"
        end

        results = Array(response['result'])
        best = best_exact_match(results, name)
        return [] unless best
        [ChecklistBankTaxonNameAdapter.new(best)]
      end

      #
      # Returns lineage array from highest ancestor down to current taxon
      #
      def get_lineage_for(taxon)
        json =
          if taxon.respond_to?(:json) && taxon.json['classification'].present? ?
            taxon.json : nil # our API response returns classification already so no need for another API call?
          end

          lineage = [taxon]

        if json
          classification = json['classification'] || []

          # skip the current taxon (last element), since it's already in lineage above from richer usage key
          classification[0...-1].reverse_each do |ancestor|
            lineage << ChecklistBankTaxonAdapter.new(ancestor)
          end
        end

        lineage.compact
      end

      #
      # Gets phylum object from lineage.
      #
      def get_phylum_for(taxon, lineage = nil)
        lineage ||= get_lineage_for(taxon)

        # lineage is bottom up for grafting checks
        phylum = lineage.reverse.find { |t| t.rank&.downcase == 'phylum' }

        phylum ||= lineage.last.phylum # not sure of this fallback line in older code

        phylum
      end
    end

    #
    # Adapts ChecklistBank search result into TaxonName
    #
    class ChecklistBankTaxonNameAdapter
      include ModelAdapter

      attr_accessor :json
      alias :taxon_name :adaptee

      def initialize(json, params = {})
        @json = json
        @usage = json['usage'] || {}

        @adaptee = TaxonName.new(params)

        # TODO should we consider recording taxon authorship from API?
        taxon_name.name              = scientific_name
        taxon_name.lexicon           = get_lexicon
        taxon_name.is_valid          = get_is_valid
        taxon_name.source            = ChecklistBankNameProvider.source
        taxon_name.source_identifier = @json['id']
        taxon_name.source_url        = source_url
        taxon_name.taxon             = taxon
        taxon_name.name_provider     = "ChecklistBankNameProvider"
        taxon_name.valid?
        taxon_name
      end

      # Always re-check persisted taxon
      # Override taxon to make sure we always check to see if a taxon for this
      # name has been saved since the creation of this name's temporary taxon
      def taxon
        @taxon ||= get_taxon
      end

      # Overriden to make sure we always check to see if a taxon for this
      # name has been saved since the creation of this name's temporary taxon
      def save
        if taxon_name.taxon.nil? || taxon_name.taxon.new_record?
          taxon_name.taxon = taxon
        end

        taxon_name.save
      end

      protected

      def service
        @service ||= ChecklistBank.new(10)
      end

      def scientific_name
        usage_name['scientificName']
      end 

      def usage_name
        @usage['name'] || {}
      end

      def source_url
        usage_name['link'] ||
          "https://www.catalogueoflife.org/data/taxon/#{@json['id']}"
      end

      def dataset_key
        @usage['datasetKey'] ||
          ChecklistBankNameProvider::PRIMARY_DATASET_ID
      end

      def get_lexicon
        lex = 
          if usage_name['type'] == 'scientific'
            TaxonName::LEXICONS[:SCIENTIFIC_NAMES] # does our search API capture vernacular names?
          # TODO: handle vernacular names after finding how API shows them 
        end
        lex == 'unspecified' ? nil : lex
      end

      def get_is_valid
        accepted_statuses = %w[
          accepted
          provisionally accepted
        ]

        accepted_statuses.include?(
          @usage['status'].to_s.downcase
        )
      end

      def get_taxon
        source_json =
            if accepted_sciname?
            @json
            else
            accepted_usage_json
            end

        taxon = ChecklistBankTaxonAdapter.new(source_json)

        #
        # Prevent duplicate taxon names from callbacks
        
        # This is necessary because calling save here runs the validations,
        # sees that the Taxon is new and declares the lexion validation ok,
        # then saves the new taxon, which would fire the after save callback
        # creating another taxon name, and then this taxon name gets
        # created, resulting in duplicate, invalid taxon names.
        taxon.skip_new_taxon_name = true if
          taxon.respond_to?(:skip_new_taxon_name=)

        taxon
      end

      ACCEPTED_STATUSES = [
        "accepted",
        "provisionally accepted"
        ].freeze
      def accepted_sciname?
        ACCEPTED_STATUSES.include?(
            @usage['status'].to_s.downcase
          )        
      end
      def accepted_usage_json # for synonyms
        accepted = @usage['accepted']
        return @json unless accepted
        
        # TODO maybe log this directly as junior synonym into inat tree just like when curators merge taxons while adding correct parent senior taxon to synonym
        # search for synonym's parent with its scientific name 
        accepted_name = accepted['name']['scientificName']
        res = service.search(accepted_name)
        results = res['result'] || []
        provider = ChecklistBankNameProvider.new
        provider.best_exact_match(results, accepted_name) || @json
    end

    #
    # Adapts ChecklistBank classification object into Taxon
    #
    class ChecklistBankTaxonAdapter
      include ModelAdapter

      attr_accessor :json
      alias :taxon :adaptee

      def initialize(json, params = {})
        @json = json
        usage_name =
        json.dig('usage', 'name') || json
        usage =
        json.dig('usage') || json

        @adaptee = Taxon.new(params)

        @adaptee.name               = usage_name['scientificName'] || usage_name['name']
        @adaptee.rank               = usage_name['rank'] || json['rank']
        @adaptee.source             = ChecklistBankNameProvider.source
        @adaptee.source_identifier  = usage['id']
        @adaptee.source_url         = build_source_url
        @adaptee.name_provider      = "ChecklistBankNameProvider"
        @adaptee.valid?
        @adaptee
      end

      protected

      def build_source_url
        "https://www.catalogueoflife.org/data/taxon/#{json['id']}"
      end
    end
  end
end
