class AddAdminOnlyToWikiPages < ActiveRecord::Migration
  def change
    add_column :wiki_pages, :admin_only, :boolean, default: false
  end
end
