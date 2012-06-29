class TaxonChange < ActiveRecord::Base
  belongs_to :taxon
  has_many :taxon_change_taxa, :dependent => :destroy
  belongs_to :source
  has_many :comments, :as => :parent, :dependent => :destroy
  belongs_to :user

end