require 'ratatosk/model_adapter'

module Ratatosk
  module NameProviders
    #
    # Concrete strategy for getting names from the Catalogue of Life
    #
    class ColNameProvider
      def initialize
        @service = CatalogueOfLife.new
      end

      def find(name)
        hxml = @service.search(:name => name, :response => 'full')
        unless hxml.errors.blank?
          raise NameProviderError, "Failed to parse the response from the Catalogue of Life"
        end
        hxml.search('//result').map do |r|
          ColTaxonNameAdapter.new(r)
        end
      end

      #
      # Finds a taxon's ancestors from the name provider and returns an array
      # of them as *new* Taxon objects up until there is one already in our
      # database. Thus, the first Taxon in the array should either be a new
      # Kingdom or an existing saved Taxon that is already in our local tree.
      #
      def get_lineage_for(taxon)
        # If taxon was already fetched with classification data, use that
        if taxon.class != Taxon && taxon.hxml && taxon.hxml.at('classification')
          hxml = taxon.hxml
        else
          hxml = @service.search(:id => taxon.source_identifier, :response => 'full' )
        end
        lineage = [taxon]

        # walk UP the CoL lineage creating new taxa
        [hxml.search('classification/taxon')].flatten.reverse_each do |ancestor_hxml|
          lineage << ColTaxonAdapter.new(ancestor_hxml)
        end
        lineage.compact
      end
      
      # Gets the phylum name for this taxon.
      def get_phylum_for(taxon, lineage = nil)
        lineage ||= get_lineage_for(taxon)
        phylum = lineage.select{|t| t.rank && t.rank.downcase == 'phylum'}.first
        phylum ||= lineage.last.phylum
        phylum
      end
    end

    class ColTaxonNameAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon_name :adaptee
      
      #
      # Initialize with an Hpricot object of a single CoL XML response
      #
      def initialize(hxml, params = {})
        binding.pry
        @adaptee = TaxonName.new(params)
        @hxml = hxml
        taxon_name.name = @hxml.at('name').inner_text
        taxon_name.lexicon = get_lexicon
        taxon_name.is_valid = get_is_valid
        taxon_name.source = Source.find_by_title('Catalogue of Life')
        taxon_name.source_identifier = @hxml.at('//id').inner_text
        taxon_name.source_url = @hxml.at('url').inner_text
        taxon_name.taxon = taxon
        taxon_name.name_provider = "ColNameProvider"
      end
      
      # Override taxon to make sure we always check to see if a taxon for this
      # name has been saved since the creation of this name's temporary taxon
      def taxon
        @taxon ||= get_taxon
      end
      
      # Overriden to make sure we always check to see if a taxon for this
      # name has been saved since the creation of this name's temporary taxon
      def save
        if taxon_name.taxon.nil? or taxon_name.taxon.new_record?
          taxon_name.taxon = taxon
        end
        taxon_name.save
      end
      
      protected

      def get_lexicon
        lex = case @hxml.at('Class')
          when "Scientific Name"
            "Scientific Names"
          when "Vernacular Name"
            @hxml.at("Language")
          else
            nil
          end
        lex
      end

      def get_is_valid
        return true if is_comname?
        ["accepted name", "provisionally accepted name"].include?(@hxml.at_xpath('name_status').inner_text)
      end

      #
      # Test if this is a common / vernacular name
      #
      def is_comname?
        @hxml.at_xpath('rank').nil?
      end

      def get_taxon
        if is_accepted_sciname?
          taxon = ColTaxonAdapter.new(@hxml)
        else
          taxon = ColTaxonAdapter.new(accepted_name_hxml)
        end
        
        # This is necessary because calling save here runs the validations,
        # sees that the Taxon is new and declares the lexion validation ok,
        # then saves the new taxon, which would fire the after save callback
        # creating another taxon name, and then this taxon name gets
        # created, resulting in duplicate, invalid taxon names.
        taxon.skip_new_taxon_name = true
        
        taxon
      end

      def is_accepted_sciname?
        accepted_name.nil?
      end

      def accepted_name
        accepted_name_hxml.at_xpath('name').inner_text rescue nil
      end

      def accepted_name_hxml
        @accepted_name_hxml ||= @hxml.at_xpath('accepted_name')
      end
    end

    class ColTaxonAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon :adaptee
      
      #
      # Initialize with an Hpricot object of a single CoL XML response
      #
      def initialize(hxml, params = {})
        @adaptee = Taxon.new(params)
        @hxml = hxml
        @adaptee.name               = @hxml.at('name').inner_text
        @adaptee.rank               = @hxml.at('rank').inner_text.downcase
        @adaptee.source             = Source.find_by_title('Catalogue of Life')
        @adaptee.source_identifier  = @hxml.at('id').inner_text
        @adaptee.source_url         = @hxml.at('url').inner_text
        @adaptee.name_provider      = "ColNameProvider"
      end
    end


    class UBioNameProvider
      attr_accessor :service, :PREFERRED_CLASSIFICATIONS, 
                              :REJECTED_CLASSIFICATIONS

      def initialize(api_key=nil)
        api_key ||= UBIO_KEY
        @service = UBioService.new(api_key)
        
        # List of classifications from uBio we like. To fetch an updated list
        # of all available classifications, try this:
        @PREFERRED_CLASSIFICATIONS = [
          'Species2000 & ITIS Catalogue of Life: 2011',
          'Species2000 & ITIS Catalogue of Life: 2010',
          'Species2000 & ITIS Catalogue of Life: 2009',
          'Species2000 & ITIS Catalogue of Life: 2008',
          'Species2000 & ITIS Catalogue of Life: 2007',
          'Species 2000',
          'Integrated Taxonomic Information System ITIS (July. 2004)',
          'Integrated Taxonomic Information System ITIS (Nov. 10 2003)',
          'Integrated Taxonomic Information System ITIS (Aug. 10 2003)',
          'Integrated Taxonomic Information System (ITIS)',
          'GBIF Hierarchy of Higer Taxa',
          'uBiota 2008-03-20T10:36:50-04:00',
          'NCBI Taxonomy'
        ]
        
        @REJECTED_CLASSIFICATIONS = ['PreUnion']
      end

      def find(name)
        begin
          results = get_keepers(name, @service.simple_namebank_search(name))
          rdfs = results.map do |r|
            @service.lsid(:namespace => 'namebank', :object => r[:namebankID])
          end.compact
        rescue UBioConnectionError => e
          raise NameProviderError, e.message
        end
        
        taxon_names = rdfs.map do |rdf|
          begin
            UBioTaxonNameAdapter.new(rdf, :np => self)
          rescue TaxonNameAdapterError => e
            # We could also forget these errors and rely on the new TaxonNames
            # being invalid. Not sure which way is best. KMU 2008-08
            nil
          end
        end.compact
        
        # For synonyms in the same taxonomic group, only keep one (canonical 
        # if possible)
        taxon_names_by_tgroup = taxon_names.group_by do |tn|
          tgroup = tn.hxml.at('//ubio:taxonomicGroup').inner_text.strip rescue nil
          tgroup
        end
        keepers = taxon_names_by_tgroup.delete(nil) || []
        taxon_names_by_tgroup.each do |tgroup, tnames|
          tnames.group_by(&:name).each do |tname, synonyms|
            keeper = synonyms.detect do |s| 
              (s.hxml.at('//ubio:lexicalStatus').inner_text rescue nil) == 'Canonical form'
            end
            keeper ||= synonyms.first
            keepers << keeper
          end
        end
        
        # Try to sort the names so canonicals are first
        keepers = keepers.sort do |a,b|
          a_canonical = (a.hxml.at('//ubio:lexicalStatus').inner_text rescue nil) == 'Canonical form'
          b_canonical = (b.hxml.at('//ubio:lexicalStatus').inner_text rescue nil) == 'Canonical form'
          if a_canonical && !b_canonical
            -1
          elsif b_canonical && !a_canonical
            1
          else
            0
          end
        end
        
        keepers
      end

      def get_lineage_for(taxon)
        # search cbank for this taxon in its many classifications
        cbankr_results = @service.classificationbank_search(
          :namebankID => taxon.source_identifier)
        
        # choose a classification, preferrably a nice and shiny one
        cbank_id = choose_cbank_id(cbankr_results)

        # call uBio again to fetch the ClassificationBank object w/ ancestry
        cbank_obj = @service.classificationbank_object( 
                      :hierarchiesID => cbank_id, 
                      :ancestryFlag => 1 )
        
        # walk UP the lineage creating new taxa if they don't exist, and
        # stopping if we find one
        lineage = [taxon]
        cbank_obj.search('//ancestry/value').each do |ancestor|
          namebank_id = ancestor.at('namebankID').inner_text
          cbank_id = ancestor.at('classificationBankID').inner_text
          begin
            rdf = @service.lsid(:namespace => 'classificationbank', 
                                :object => cbank_id)
            new_taxon = UBioTaxonAdapter.new(rdf, :name_provider => self)
          rescue TaxonAdapterError
            # if the cbank object fails, try converting from namebank
            rdf = @service.lsid(:namespace => 'namebank', 
                                :object => namebank_id)
            new_taxon = UBioTaxonAdapter.new(rdf)
          rescue UBioConnectionError => e
            taxon.logger.error("Error while running get_lineage_for(#{taxon}): #{e}")
            raise NameProviderError, e.message
          rescue StandardError => e
            raise NameProviderError, "uBio bonked: #{e}"
          end

          lineage << new_taxon
        end

        lineage.compact
      end

      def get_phylum_for(taxon, lineage = nil)
        # Try to avoid calling uBio a billion times using their 
        # taxonomicGroup element
        if taxon.class != Taxon && (taxaonomic_group = taxon.hxml.at('ubio:taxonomicGroup'))
          if taxonomic_group_taxon = Taxon.find_by_name(taxaonomic_group.inner_text)
            return taxonomic_group_taxon if taxonomic_group_taxon.rank == 'phylum'
            return taxonomic_group_taxon.phylum
          end
        end
        
        begin
          lineage ||= get_lineage_for(taxon)
        rescue NameProviderError
          return nil
        end
        # puts "[DEBUG] lineage for #{taxon}: #{lineage.map(&:name).join(', ')}"
        phylum = lineage.detect{|t| t.rank && t.rank.downcase == 'phylum'}
        phylum ||= lineage.last.phylum
        phylum
      end
      
      protected

      #
      # Chooses a uBio ClassificationBank object ID from an Hpricot return
      # from classificationbank_search.  Tries to choose classifications that
      # work well for us.
      #
      def choose_cbank_id(cbank_response)
        cbank_results = cbank_response.search('//seniorNames/value')
        if cbank_results.empty?
          raise NameProviderError, 
                "uBio doesn't have any classification data for this taxon"
        end

        cbank_title_ids = {}
        cbank_results.each do |c|
          cbank_title = Base64.decode64(c.at('classificationTitle').inner_text)
          cbank_id = c.at('classificationBankID').inner_text
          if cbank_title and cbank_id
            cbank_title_ids[cbank_title] = cbank_id
          end
        end

        preferred_id = nil
        @PREFERRED_CLASSIFICATIONS.each do |c|
          break if preferred_id = cbank_title_ids[c]
        end
        if preferred_id.nil?
          preferred = cbank_title_ids.select do |title, id|
            not @REJECTED_CLASSIFICATIONS.include?(title)
          end.first
          if preferred.nil?
            raise NameProviderError, 
                  "uBio only has classification data for this taxon " + 
                  "from incompatible classifications " + 
                  "(#{cbank_title_ids.keys.join(', ')})"
          end
          preferred_id = preferred.last
        end
        preferred_id
      end

      #
      # Filter a simple_namebank_search response to keep the size down (so we
      # don't call uBio 2 trillion times for large responses) and to ensure
      # that the name searched for gets kept.
      #
      def get_keepers(name, results)
        keepers = results[0..9]
        if exact_match = results.detect {|r| r[:name] == name}
          unless keepers.map {|k| k[:name]}.include?(name)
            keepers.unshift(exact_match)
            keepers.pop
          end
        end
        keepers
      end
    end
  end # module NameProviders
end # module Ratatosk
