gt ||= guide_taxon
image_sizes ||= %w(thumb small medium large)
local_asset_path ||= "files"
xml.GuideTaxon :position => gt.position do
  xml.name gt.name
  xml.displayName(gt.display_name) unless gt.display_name == gt.name
  xml.taxonID gt.taxon_id if gt.taxon_id
  gt.tags.map(&:name).each do |tag|
    tag_to_xml(tag, xml)
  end
  gt.guide_photos.sort_by{|gp| gp.position.to_i}.each do |gp|
    xml.GuidePhoto :position => gp.position do
      image_sizes.each do |s|
        next unless url = gp.send("#{s}_url")
        xml.href url, :type => "remote", :size => s
        xml.href(File.join(local_asset_path, gp.asset_filename(size: s)), :type => "local", :size => s) if local_asset_path
      end
      xml.dc(:description, gp.description) unless gp.description.blank?
      xml.attribution gp.attribution
      xml.dcterms :rightsHolder, gp.attribution_name
      xml.dc :license, url_for_license(gp.license_code) unless gp.license_code.blank?
      gp.tags.map(&:name).each do |tag|
        tag_to_xml(tag, xml)
      end
    end
  end
  gt.guide_ranges.sort_by(&:position).each do |gr|
    xml.GuideRange :position => gr.position do
      image_sizes.each do |s|
        next unless gr.respond_to?("#{s}_url") && (url = gr.send("#{s}_url")) && !url.blank?
        xml.href url, :type => "remote", :size => s
        xml.href(File.join(local_asset_path, gr.asset_filename(size: s)), :type => "local", :size => s) if local_asset_path
      end
      xml.attribution gr.attribution
      xml.dcterms :rightsHolder, gr.attribution_name
      xml.dc :license, url_for_license(gr.license)
    end
  end
  gt.guide_sections.sort_by{|gs| gs.position.to_i}.each do |gs|
    xml.GuideSection :position => gs.position do
      xml.dc :title, gs.title
      xml.dc :body do
        xml.cdata! formatted_user_text(gs.description)
      end
      xml.attribution gs.attribution
      xml.dcterms :rightsHolder, gs.rights_holder
    end
  end
end
