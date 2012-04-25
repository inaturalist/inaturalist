require 'ratatosk/model_adapter'

class TaxonNameAdapterError < StandardError; end
class TaxonAdapterError < StandardError; end
class NameProviderError < StandardError; end

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
        lex = if @hxml.at_xpath('rank')
          TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
        elsif hxml.at('//language')
          @hxml.at('//language').inner_text.downcase
        else
          nil
        end
        lex == 'unspecified' ? nil : lex
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

    class UBioTaxonAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon :adaptee

      def initialize(hxml, params = {})
        @np = params.delete(:np)
        @service = @np.service rescue UBioService.new(UBIO_KEY)
        @adaptee = Taxon.new(params)
        @hxml = hxml
        taxon.name = get_name
        taxon.rank = @hxml.at('//gla:rank').inner_text.downcase rescue nil
        taxon.source = Source.find_by_title('uBio')
        taxon.source_identifier = get_namebank_id
        taxon.source_url = 'http://www.ubio.org/browser/details.php?' +
                           'namebankID=' + taxon.source_identifier

        taxon.name_provider = "UBioNameProvider"
      end

      protected

      def get_name
        begin
          name = @hxml.at('//ubio:canonicalName').inner_text
        rescue NoMethodError
          begin
            name = @hxml.at('//dc:title').inner_text
          rescue NoMethodError
            # without any kind of name in the RDF response, we can't make a taxon
            raise TaxonAdapterError, "Couldn't find a name in a uBio RDF response"
          end
        end
        name
      end

      def get_namebank_id
        # CBank and NBank store the namebank LSID in different places
        if @hxml.at('//rdf:Description')['about'] =~ /classificationbank/
          lsid = @hxml.at('//ubio:namebankIdentifier')['resource']
        else
          lsid = @hxml.at('//dc:identifier').inner_text
        end

        namebank_id = lsid.split(':')[4] # 4th term should be the identifier
        if namebank_id.nil?
          raise TaxonAdapterError, 
                "Couldn't find a valid LSID in uBio's RDF response"
        end
        namebank_id
      end
    end

    #
    # Adapt a uBio namebank RDF response to an iNat TaxonName
    #
    class UBioTaxonNameAdapter
      include ModelAdapter
      attr_accessor :hxml, :service, :np
      alias :taxon_name :adaptee

      def initialize(hxml, params = {})
        @np = params.delete(:np)
        @service = @np.service rescue UBioService.new(UBIO_KEY)
        @hxml = hxml
        @adaptee = TaxonName.new(params)
        
        taxon_name.source = Source.find_by_title('uBio')
        taxon_name.source_identifier = get_namebank_id
        taxon_name.source_url = 'http://www.ubio.org/browser/details.php?namebankID=' + get_namebank_id
        taxon_name.name = get_name
        taxon_name.lexicon = get_lexicon
        taxon_name.is_valid = get_is_valid
        taxon_name.taxon = taxon
        taxon_name.name_provider = "UBioNameProvider"
      end
      
      # Override taxon to make sure we always check to see if a taxon for this
      # name has been saved since the creation of this name's temporary taxon
      def taxon
        if taxon_name.taxon.nil? or taxon_name.taxon.new_record?
          begin
            get_taxon
          rescue TaxonAdapterError => e
            raise TaxonNameAdapterError, 
              "Couldn't set a taxon.  Why?  #{e.message}"
          end
        else
          taxon_name.taxon
        end
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

      def get_name
        begin
          name = @hxml.at('//ubio:canonicalName').inner_text
        rescue NoMethodError
          begin
            name = @hxml.at('//dc:title').inner_text
          rescue NoMethodError
            # without any kind of name in the RDF response, we can't make a taxon
            raise TaxonNameAdapterError, "Couldn't find a name in a uBio RDF " +
                                         "response"
          end
        end
        name
      end

      def get_lexicon
        @hxml.at('//dc:language').inner_text.downcase rescue TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
      end

      def get_is_valid
        if is_comname?
          true
        else
          @hxml.at('//ubio:hasSYNConcept') ? false : true
        end
      end

      def get_namebank_id
        begin
          lsid = @hxml.at('//dc:identifier').inner_text
        rescue NoMethodError
          raise TaxonNameAdapterError, "uBio returned a taxon without an identifier"
        end
        lsid.split(':')[4] # 4th term should be identifier
      end

      def get_taxon
        if is_sciname? and is_valid?
          taxon = UBioTaxonAdapter.new(@hxml)
        else
          taxon = is_comname? ? comname_taxon : sciname_taxon
        end
        
        # This is necessary because calling save here runs the validations,
        # sees that the Taxon is new and declares the lexion validation ok,
        # then saves the new taxon, which would fire the after save callback
        # creating another taxon name, and then this taxon name gets
        # created, resulting in duplicate, invalid taxon names.
        taxon.skip_new_taxon_name = true
        
        taxon
      end

      def is_comname?
        not is_sciname?
      end

      def is_sciname?
        @hxml.at('//dc:language').nil?
      end
      
      #
      # Return a UBioTaxonAdapter for this name if this is a common name
      #
      def comname_taxon
        begin
          taxon_namebank_lsid = @hxml.at('//gla:parent')['resource']
        rescue
          # this is a phenomenally brittle workaround for what seems like an
          # Hpricot bug with selecting certaing empty elements...
          taxon_namebank_lsid = @hxml.at('//dc:language').next_sibling['resource']
        end
        begin
          UBioTaxonAdapter.new(@service.lsid(taxon_namebank_lsid)).taxon
        rescue UBioConnectionError => e
          logger.error("Error in UBioTaxonNameAdapter#comname_taxon while " + 
            "running @service.lsid(#{taxon_namebank_lsid}): #{e}")
          raise NameProviderError, e.message
        end
      end


      #
      # Return a UBioTaxonAdapter for this name if this is a scientific name
      #
      def sciname_taxon
        cbank_rdfs = {}
        
        # Assemble the different representations of this name within different
        # classifications so we can attempt to choose one.
        @hxml.search('ubio:hasSYNConcept').each do |syn|
          # Fetch the RDF for this ClassificationBank object
          begin
            cbank_lsid_rdf = @service.lsid(syn['resource'])
          rescue UBioConnectionError => e
            # If uBio isn't responding to requests for ClassificationBank info
            # (which seems to happen occasionally), use the NameBank RDF
            # instead.  We probably won't be able to graft it, but at least
            # we'll have a taxon
            logger.error("[Ratatosk] Error in " + 
              "UBioTaxonNameAdapter#sciname_taxon while running " + 
              "@service.lsid(#{syn['resource']}).  Attempting to " + 
              "continue using the Namebank RDF.  Error: #{e}")
            cbank_lsid_rdf = @hxml
          end
          begin
            cfn_name = cbank_lsid_rdf.at('ubio:classificationName').inner_text
            cbank_rdfs[cfn_name] = cbank_lsid_rdf
          rescue NoMethodError
            cbank_rdfs['unknown'] = cbank_lsid_rdf
          end

          begin
            canonical_name = cbank_lsid_rdf.at('ubio:canonicalName').inner_text
          rescue NoMethodError
            logger.info("[Ratatosk] The ClassificationBank object for had " + 
                        "no canonical name, so we're ignoring it.")
            next
          end

          # If we already know about its accepted scientific name, stop this 
          # madness
          if taxon = Taxon.find_by_name(canonical_name)
            return taxon
          end
        end

        # if don't know about any of these taxa, try to find one in a preferred
        # classification scheme to ease the grafting process, defaulting to a 
        # random one.
        # Note: this might even be necessary.  It's not clear to me whether a
        # set ubio:hasSYNConcept entities always reference the same namebank
        # object in different classifications.  That seems to be the case.
        begin
          preferred_classifications = @np.PREFERRED_CLASSIFICATIONS
        rescue
          raise TaxonNameAdapterError, 
                "Can't fetch a taxon for this TaxonName from uBio without " +
                "a name provider object"
        end
        preferred_classifications.each do |c|
          break if preferred_rdf = cbank_rdfs[c]
        end
        preferred_rdf ||= cbank_rdfs.values.first

        # now that we've chosen a classification, let's set the damn taxon
        UBioTaxonAdapter.new(preferred_rdf)
      end
    end
  end # module NameProviders
end # module Ratatosk
