class CreateFrequencyTables < ActiveRecord::Migration
  def change
    create_table :frequency_cells do |t|
      t.integer :swlat
      t.integer :swlng
    end
    add_index :frequency_cells, [:swlat, :swlng]

    create_table :frequency_cell_month_taxa, id: false do |t|
      t.integer :frequency_cell_id
      t.integer :month
      t.integer :taxon_id
      t.integer :count
    end
    add_index :frequency_cell_month_taxa, :frequency_cell_id
    add_index :frequency_cell_month_taxa, :taxon_id
  end
end
