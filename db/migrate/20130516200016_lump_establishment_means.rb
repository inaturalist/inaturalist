class LumpEstablishmentMeans < ActiveRecord::Migration
  def up
    ListedTaxon.where(establishment_means: [ "naturalised", "invasive", "managed" ]).
      update_all(establishment_means: "introduced")
  end

  def down
    # there is no going back
  end
end
