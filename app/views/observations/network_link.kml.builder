xml.instruct!
xml.kml "xmlns" => "http://www.opengis.net/kml/2.2" do
  xml.Document do
    xml.NetworkLink do 
      xml.name @net_hash[:name]
      xml.visibility 1
      xml.open 1
      xml.snippet @net_hash[:snippet]
      xml.description @net_hash[:description]
      xml.Link :id => @net_hash[:link_id]+"obs" do
        xml.href @net_hash[:href]
        xml.refreshMode "onInterval"
        xml.refreshInterval "3600"
        xml.viewRefreshMode "onStop"
        xml.viewRefreshTime 1
        xml.viewBoundScale ".75"
        xml.viewFormat "swlng=[bboxWest]&swlat=[bboxSouth]&nelng=[bboxEast]&nelat=[bboxNorth]"
      end
    end
  end
end
