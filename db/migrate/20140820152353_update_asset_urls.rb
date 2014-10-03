class UpdateAssetUrls < ActiveRecord::Migration
  def up
    wiki_pages = WikiPage.where("content like '%/images%' OR content like '%/stylesheets%'")
    wiki_pages.each do |p|
      p.content = p.content.gsub(/(['"]|inaturalist\.org)\/images/i, "\\1/assets")
      p.content = p.content.gsub(/(['"]|inaturalist\.org)\/stylesheets/i, "\\1/assets")
      p.save!
    end
  end

  def down
    wiki_pages = WikiPage.where("content like '%/assets%'")
    wiki_pages.each do |p|
      # change all assets back to images
      p.content = p.content.gsub(/(['"]|inaturalist\.org)\/assets/i, "\\1/images")
      # some of those will have been the stylesheets, so convert those now
      p.content = p.content.gsub(/(link href=['"])\/images/i, "\\1/stylesheets")
      p.save!
    end
  end
end
