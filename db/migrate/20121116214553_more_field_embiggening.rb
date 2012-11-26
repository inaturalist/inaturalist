class MoreFieldEmbiggening < ActiveRecord::Migration
  def up
    change_column :sources, :citation, :string, :limit => 512
  end

  def down
    change_column :sources, :citation, :string, :limit => 256
  end
end
