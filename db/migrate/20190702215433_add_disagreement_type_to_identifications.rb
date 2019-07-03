class AddDisagreementTypeToIdentifications < ActiveRecord::Migration
  def change
    add_column :identifications, :disagreement_type, :string
  end
end
