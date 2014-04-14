class AddNativeResponseToSounds < ActiveRecord::Migration
  def change
  	add_column :sounds, :native_response, :text
  end
end
