class ChangeTaxonRankLevelToFloat < ActiveRecord::Migration
  def up
    change_column :taxa, :rank_level, :float
    execute <<-SQL
      UPDATE taxa SET rank_level = #{Taxon::PARVORDER_LEVEL} WHERE rank = '#{Taxon::PARVORDER}';
      UPDATE taxa SET rank_level = #{Taxon::ZOOSUBSECTION_LEVEL} WHERE rank = '#{Taxon::ZOOSUBSECTION}'
    SQL
    Taxon.elastic_index!( scope: Taxon.where( "rank IN ('parvorder', 'zoosubsection')" ) )
  end

  def down
    change_column :taxa, :rank_level, :integer
    Taxon.elastic_index!( scope: Taxon.where( "rank IN ('parvorder', 'zoosubsection')" ) )
  end
end
