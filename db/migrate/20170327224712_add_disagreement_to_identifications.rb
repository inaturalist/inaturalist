class AddDisagreementToIdentifications < ActiveRecord::Migration
  def change
    add_column :identifications, :disagreement, :boolean
  end
end
