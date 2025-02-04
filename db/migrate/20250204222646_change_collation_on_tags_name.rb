# frozen_string_literal: true

class ChangeCollationOnTagsName < ActiveRecord::Migration[6.1]
  def up
    # This makes LOWER() behave the same way on Turkic characters as Ruby's
    # downcase method, which allows existing Turkic tags to be found
    change_column :tags, :name, :string, limit: 255, collation: "und-x-icu"
  end

  def down
    change_column :tags, :name, :string, limit: 255, collation: "default"
  end
end
