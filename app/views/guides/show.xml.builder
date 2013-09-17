guide ||= @guide
guide_taxa ||= @guide_taxa || guide.guide_taxa
image_sizes ||= %w(thumb small medium)
local_asset_path = "files"
xml.instruct!
xml.INatGuide "xmlns:dc" => "http://purl.org/dc/elements/1.1/" do
  xml.dc :title, guide.title
  xml.dc :description, guide.description
  guide_taxa.each do |gt|
    xml.GuideTaxon :position => gt.position do
      xml.name gt.name
      xml.displayName gt.display_name
      gt.guide_photos.each do |gp|
        xml.GuidePhoto :position => gp.position do
          image_sizes.each do |s|
            next unless url = gp.send("#{s}_url")
            xml.href url, :type => "remote", :size => s
            xml.href(File.join(local_asset_path, guide_asset_filename(gp, :size => s)), :type => "local", :size => s) if local_asset_path
          end
          xml.description gp.description unless gp.description.blank?
        end
      end
      gt.guide_ranges.each do |gr|
        xml.GuideRange do
          image_sizes.each do |s|
            next unless gr.respond_to?("#{s}_url") && url = gr.send("#{s}_url")
            xml.href gr.send("#{s}_url"), :type => "remote", :size => s
            xml.href(File.join(local_asset_path, guide_asset_filename(gr, :size => s)), :type => "local", :size => s) if local_asset_path
          end
        end
      end
      gt.guide_sections.each do |gs|
        xml.GuideSection :position => gs.position do
          xml.dc :title, gs.title
          xml.dc :body do
            xml.cdata! gs.description
          end
        end
      end
    end
  end
end
