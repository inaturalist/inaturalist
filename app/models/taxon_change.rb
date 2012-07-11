class TaxonChange < ActiveRecord::Base
  belongs_to :taxon
  has_many :taxon_change_taxa, :dependent => :destroy
  belongs_to :source
  has_many :comments, :as => :parent, :dependent => :destroy
  belongs_to :user
  
  validates_presence_of :taxon_id
  
  def self.commit_taxon_change(taxon_change_id)
    unless taxon_change = TaxonChange.find_by_id(taxon_change_id)
      return
    end
    TaxonChange.update_all(["committed_on = ?", Time.now],["id = ?", taxon_change.id])
    case taxon_change.class.name when 'TaxonSplit'
      Taxon.update_all({:is_active => false},["id = ?", taxon_change.taxon_id])
      Taxon.update_all({:is_active => true},["id in (?)", taxon_change.taxon_change_taxa.map{|tct| tct.taxon_id}])
      TaxonSplit.send_later(:update_observations_later, taxon_change.id, :dj_priority => 2)
    when 'TaxonMerge'
      Taxon.update_all({:is_active => false},["id in (?)", taxon_change.taxon_change_taxa.map{|tct| tct.taxon_id}])
      Taxon.update_all({:is_active => true},["id = ?", taxon_change.taxon_id])
      TaxonMerge.send_later(:update_observations_later, taxon_change.id, :dj_priority => 2)
    when 'TaxonSwap'
      Taxon.update_all({:is_active => false},["id in (?)", taxon_change.taxon_change_taxa.map{|tct| tct.taxon_id}])
      Taxon.update_all({:is_active => true},["id = ?", taxon_change.taxon_id])
      TaxonSwap.send_later(:update_observations_later, taxon_change.id, :dj_priority => 2)
    when 'TaxonDrop'
      Taxon.update_all({:is_active => false},["id = ?", taxon_change.taxon_id])
    end
  end

end
