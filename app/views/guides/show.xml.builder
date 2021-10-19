guide ||= @guide
guide_taxa ||= @guide_taxa || guide.guide_taxa
xml.instruct!
xml.INatGuide "xmlns:dc" => "http://purl.org/dc/elements/1.1/", 
              "xmlns:dcterms" => "http://purl.org/dc/terms/",
              "xmlns:eol" => "http://www.eol.org/transfer/content/1.0" do
  xml.dc :title, guide.title
  xml.dc :description, guide.description
  xml.eol :agent, {:role => "compiler"}, guide.user.name.blank? ? guide.user.login : guide.user.name
  xml.dc :license, url_for_license(guide.license)
  if ( this_ngz_url = ngz_url( guide ) )
    xml.ngz do
      xml.size number_to_human_size(guide.ngz_size)
      xml.href this_ngz_url
    end
  end
  guide_taxa.each do |gt|
    xml << render("guide_taxa/guide_taxon", :guide_taxon => gt)
  end
end
