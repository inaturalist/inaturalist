class LumpEstablishmentMeans < ActiveRecord::Migration
  def up
    ListedTaxon.update_all("establishment_means = 'introduced'", "establishment_means IN ('naturalised', 'invasive', 'managed')")
  end

  def down
    # there is no going back
  end
end
