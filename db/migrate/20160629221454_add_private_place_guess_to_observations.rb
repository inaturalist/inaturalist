class AddPrivatePlaceGuessToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :private_place_guess, :string
  end
end
