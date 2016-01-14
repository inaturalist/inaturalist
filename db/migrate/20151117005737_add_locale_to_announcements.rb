class AddLocaleToAnnouncements < ActiveRecord::Migration
  def change
    add_column :announcements, :locale, :string
  end
end
