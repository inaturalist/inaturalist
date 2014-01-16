#could disable certain callbacks to make this faster
#Is this ok, or should it be batched or scoped differently?
class ListedTaxon
  def make_primary
    update_attribute(:primary_listing, true) unless ListedTaxon.where({taxon_id:taxon_id, place_id: place_id, primary_listing: true}).present?
  end
end

ListedTaxon.find_each do |listed_taxon|
  listed_taxon.make_primary
end
