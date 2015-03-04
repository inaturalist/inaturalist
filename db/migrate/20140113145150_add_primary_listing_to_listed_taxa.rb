class AddPrimaryListingToListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :primary_listing, :boolean

    batch_num = 0
    batch_size = 5000
    say "Calculating number of batches..."
    scope = ListedTaxon.includes(:list).where("place_id IS NOT NULL")
    num_batches = (scope.count / batch_size.to_f).round
    scope.find_in_batches(:batch_size => batch_size) do |batch|
      say "Updating batch #{batch_num} of #{num_batches} #{Time.now}"
      batch.each do |listed_taxon|
        listed_taxon.make_primary_if_no_primary_exists
      end
      batch_num += 1
    end
  end

  def self.down
    remove_column :listed_taxa, :primary_listing
  end
  
end