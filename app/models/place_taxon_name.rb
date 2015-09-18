class PlaceTaxonName < ActiveRecord::Base
  belongs_to :place, :inverse_of => :place_taxon_names
  belongs_to :taxon_name, :inverse_of => :place_taxon_names
  validates_uniqueness_of :place_id, :scope => :taxon_name_id
  validates_presence_of :place_id, :taxon_name_id

  def to_s
    "<PlaceTaxonName #{id}, place_id: #{place_id}, taxon_name_id: #{taxon_name_id}>"
  end
  
end
