xml.instruct!
@prevent_cache = "?prevent=#{rand(1024)}"

xml.kml "xmlns" => "http://www.opengis.net/kml/2.2", 
        "xmlns:atom" => "http://www.w3.org/2005/Atom"  do
  xml.Document do
    unless @observations.blank?
      xml << render(:partial => "observation", :collection => @observations)
    end
  end
end
