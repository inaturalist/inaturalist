# frozen_string_literal: true

class PopulateAssociatedAudits < ActiveRecord::Migration[6.1]
  def up
    Audited::Audit.
      where( auditable_type: %w(TaxonName PlaceTaxonName ConservationStatus) ).
      includes( :auditable ).
      find_each do | audit |
      next unless audit.auditable

      case audit.auditable_type
      when "TaxonName", "ConservationStatus"
        audit.update( associated_type: "Taxon", associated_id: audit.auditable.taxon_id )
      when "PlaceTaxonName"
        audit.update( associated_type: "Taxon", associated_id: audit.auditable.taxon_name.taxon_id )
      end
    end
  end

  def down
    say "Best not to remove this data"
  end
end
