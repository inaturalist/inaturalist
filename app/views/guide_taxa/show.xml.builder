xml.instruct!
xml.instruct! 'xml-stylesheet', {:href => asset_url('guide_taxon.xsl'), :type => 'text/xsl'}
xml.INatGuide "xmlns:dc" => "http://purl.org/dc/elements/1.1/", 
              "xmlns:dcterms" => "http://purl.org/dc/terms/",
              "xmlns:eol" => "http://www.eol.org/transfer/content/1.0" do
  xml << render("guide_taxa/guide_taxon", :guide_taxon => @guide_taxon)
end
