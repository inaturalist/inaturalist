xml.Placemark do
  xml.name @place.name
  xml.Point do
    xml.coordinates("#{@place.longitude},#{@place.latitude}")
  end
end
if @place.place_geometry
  xml.Placemark do
    xml.name "#{@place.name} Border"
    xml.Style do
      xml.LineStyle do
        xml.color 'ff9314FF'
        xml.width 5
      end
      xml.PolyStyle do
        xml.color '339314FF'
        xml.fill 1
        xml.outline 1
      end
    end
    xml << @place.place_geometry.geom.as_kml if @place.place_geometry
  end
end
