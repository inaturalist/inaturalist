class ChangeAnnouncementsLocaleToArray < ActiveRecord::Migration
  def up
    add_column :announcements, :locales, :text, array: true, default: []
    execute <<-SQL
      UPDATE announcements SET locales = ARRAY[locale] WHERE locale IS NOT NULL;
    SQL
    add_index :announcements, [ :start, :end ]
    remove_column :announcements, :locale
  end
  def down
    add_column :announcements, :locale, :string
    execute <<-SQL
      UPDATE announcements SET locale = locales[1];
    SQL
    remove_index :announcements, [ :start, :end ]
    remove_column :announcements, :locales
  end
end
