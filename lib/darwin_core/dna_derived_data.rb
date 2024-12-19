# frozen_string_literal: true

module DarwinCore
  class DnaDerivedData
    TERMS = [
      ["id", "id", nil, "observation_id"],
      ["identifier", "http://purl.org/dc/terms/identifier", nil, "id"],
      ["DNA_sequence", "http://rs.gbif.org/terms/dna_sequence", nil, "dna_sequence"],
      ["target_gene", "https://w3id.org/mixs/0000044"],
      ["seq_meth", "https://w3id.org/mixs/0000050"],
      %w(created http://purl.org/dc/terms/created),
      %w(modified http://purl.org/dc/terms/modified)
    ].freeze
    TERM_NAMES = TERMS.map {| name, _uri | name }

    ITS = "ITS"
    COI = "COI"
    HSP90 = "HSP90"

    TARGET_GENE_FIELD_NAMES = {
      ITS => [
        "DNA Barcode ITS",
        "Haplotype A (DNA Barcode ITS)",
        "Haplotype B (DNA Barcode ITS)",
        "Haplotype C (DNA Barcode ITS)"
      ],
      COI => [
        "DNA Barcode COI"
      ],
      HSP90 => [
        "DNA Barcode hsp90"
      ]
    }.freeze

    SEQUENCING_TECHNOLOGY_FIELD_NAME = "Sequencing technology"

    def self.adapt( ofv, options = {} )
      if ofv.observation_field.datatype != ObservationField::DNA
        raise "DnaDerivedData can only adapt DNA field values"
      end

      ofv.extend( InstanceMethods )
      ofv.extend( DarwinCore::Helpers )
      ofv.observation = options[:observation] if options[:observation]
      ofv.core = options[:core]
      ofv
    end

    def self.sequencing_technology_field
      @_sequencing_technology_field ||= ObservationField.
        where( datatype: ObservationField::TEXT, name: SEQUENCING_TECHNOLOGY_FIELD_NAME ).
        first
      raise "Sequencing technology field does not exist" unless @_sequencing_technology_field

      @_sequencing_technology_field
    end

    module InstanceMethods
      attr_accessor :core

      def created
        created_at.iso8601
      end

      def modified
        updated_at.iso8601
      end

      def dna_sequence
        dwc_filter_text( value )&.upcase
      end

      def target_gene
        TARGET_GENE_FIELD_NAMES.detect do | _gene, names |
          names.include?( observation_field.name )
        end&.first
      end

      def seq_meth
        # If there are multiple sequences associated with this observation, we
        # don't know which one the sequencing technology field refers to
        num_dna_ofvs = observation.observation_field_values.select do | ofv |
          ofv.observation_field.datatype == ObservationField::DNA
        end.size
        if num_dna_ofvs > 1
          return
        end

        seq_meth_ofv&.value
      end

      private

      def seq_meth_ofv
        observation.observation_field_values.detect do | ofv |
          ofv.observation_field_id == DarwinCore::DnaDerivedData.sequencing_technology_field.id
        end
      end
    end
  end
end
