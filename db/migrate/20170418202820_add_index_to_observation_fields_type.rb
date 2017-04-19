class AddIndexToObservationFieldsType < ActiveRecord::Migration
  def change
    add_index :observation_fields, :datatype
  end
end
