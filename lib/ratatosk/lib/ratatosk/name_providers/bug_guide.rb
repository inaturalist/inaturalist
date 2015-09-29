module Ratatosk
  module NameProviders
    #
    # Concrete strategy for getting names from the Catalogue of Life
    #
    class BugGuideNameProvider
      cattr_accessor :source
      
      def self.source(options = {})
        return @@source if @@source && !options[:force]
        @@source = Source.find_by_title("BugGuide") || Source.create(
          title: "BugGuide",
          in_text: "BugGuide",
          url: "http://http://bugguide.net",
          citation: "BugGuide. Iowa State University. Available from http://bugguide.net."
        )
      end

      # def service
      #   @service ||= EolService.new(timeout: 10, debug: Rails.env.development?)
      # end

      def bugguide_to_inat_taxon(t)
        t = Taxon.new(
          name: t.scientific_name, 
          rank: t.rank, 
          source: BugGuideNameProvider.source,
          name_provider: 'BugGuideNameProvider',
          source_identifier: t.id,
          source_url: t.url
        )
        t.valid? # run before_validation callbacks
        t
      end

      def find(name)
        taxon_names = []
        ::BugGuide::Taxon.search(name).each do |t|
          taxon = bugguide_to_inat_taxon(t)
          sciname = TaxonName.new(
            name: t.scientific_name, 
            lexicon: TaxonName::LEXICONS[:SCIENTIFIC_NAMES],
            source: BugGuideNameProvider.source,
            taxon: taxon
          )
          comname = unless t.common_name.blank?
            TaxonName.new(
              name: t.common_name, 
              lexicon: TaxonName::LEXICONS[:ENGLISH],
              source: BugGuideNameProvider.source,
              taxon: taxon
            )
          end
          if comname && comname.name =~ /#{name}/
            taxon_names << comname
          else
            taxon_names << sciname
          end
        end
        taxon_names
      end

      def get_lineage_for(taxon)
        bgt = ::BugGuide::Taxon.find(taxon.source_identifier)
        [bgt.ancestors.map{|t| bugguide_to_inat_taxon(t)}, taxon].flatten.reverse
      end

      def get_phylum_for(taxon, lineage = nil)
        phylum = Taxon.where(name: 'Arthropoda', rank: ::Taxon::PHYLUM).first
        phylum ||= get_lineage_for(taxon).detect{|a| a.rank == 'phylum'}
        phylum
      end
    end
  end
end
