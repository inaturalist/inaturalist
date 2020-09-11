class AddLogoToDataPartners < ActiveRecord::Migration
  def up
    change_table :data_partners do |t|
      t.attachment :logo
    end
  end

  def down
    drop_attached_file :data_partners, :logo
  end
end
