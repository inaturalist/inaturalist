# frozen_string_literal: true

class RenameTwitterPrefsToX < ActiveRecord::Migration[6.1]
  def up
    Site.all.each do | site |
      execute <<-SQL
        UPDATE preferences SET name = 'x_url' WHERE owner_type = 'Site' AND owner_id = #{site.id} AND name = 'twitter_url';
        UPDATE preferences SET name = 'x_username' WHERE owner_type = 'Site' AND owner_id = #{site.id} AND name = 'twitter_username';
        DELETE FROM preferences WHERE owner_type = 'Site' AND owner_id = #{site.id} AND name = 'twitter_sign_in';
      SQL
    end
  end

  def down
    Site.all.each do | site |
      execute <<-SQL
        UPDATE preferences SET name = 'twitter_url' WHERE owner_type = 'Site' AND owner_id = #{site.id} AND name = 'x_url';
        UPDATE preferences SET name = 'twitter_username' WHERE owner_type = 'Site' AND owner_id = #{site.id} AND name = 'x_username';
      SQL
    end
  end
end
