# frozen_string_literal: true

class CreateUsernameReservedWords < ActiveRecord::Migration[6.1]
  def change
    create_table :username_reserved_words do | t |
      t.string :word

      t.timestamps
    end
  end
end
