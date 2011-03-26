xml.instruct!
xml.kml "xmlns" => "http://www.opengis.net/kml/2.2" do

  xml.Document{
    
    xml.NetworkLink(:id=>@net_hash[:id]+"obs") do 
      xml.name(@net_hash[:name])
      xml.visibility("1")
      xml.open("1")
      xml.snippet(@net_hash[:snippet], :maxLines=>"2")
      xml.description(@net_hash[:description])
      xml.Link(:id=>(@net_hash[:link_id]+"obs")) do
        xml.href{
          if @net_hash[:href].include? '?'
            xml.cdata!(@net_hash[:href])
          else
            xml.cdata!(@net_hash[:href])
          end
        }
        #refresh options, type 1
        xml.refreshMode("onInterval")
        xml.refreshInterval("3600")

        #refresh options, type 2
        xml.viewRefreshMode("onStop")
        xml.viewRefreshTime("1")

        xml.viewBoundScale(".75")
        xml.viewFormat("swlng=[bboxWest]&swlat=[bboxSouth]&nelng=[bboxEast]&nelat=[bboxNorth]&CAMERA=[lookatLon],[lookatLat],[lookatRange],[lookatTilt],[lookatHeading]&VIEW=[horizFov],[vertFov],[horizPixels],[vertPixels],[terrainEnabled]")
      end
    end
  }
end
