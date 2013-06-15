class AddEmbedHtmlToSounds < ActiveRecord::Migration
  def change
    add_column :sounds, :embed_html, :text
  end
end
