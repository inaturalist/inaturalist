class AddTaxonFrameworkToTaxonCurators < ActiveRecord::Migration

  def up
    add_column :taxon_curators, :taxon_framework_id, :integer
    add_index :taxon_curators, :taxon_framework_id
    say "Creating taxon frameworks for all complete taxa..."
    Taxon.where( complete: true ).each do |t|
      say "\t#{t}"
      tf = TaxonFramework.create!(
        taxon: t,
        complete: true,
        rank_level: Taxon::RANK_LEVELS[t.complete_rank],
        skip_reindexing_taxa: true
      )
      t.taxon_curators.each {|tc| tc.update_attributes!( taxon_framework: tf ) }
    end
    say "You will need to reindex these taxa by hand with Taxon.reindex_taxa_covered_by( framework )"
  end

  def down
    remove_column :taxon_curators, :taxon_framework_id
  end

end
