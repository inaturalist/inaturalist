if @kml
  xml.Placemark do
    xml.name "#{@place.name} Border"
    xml.styleUrl URI.join(@site.url, "assets/index.kml#place")
    xml << @kml
  end
else
  xml.Placemark do
    xml.name @place.name
    xml.styleUrl URI.join(@site.url, "assets/index.kml#place")
    xml.Point do
      xml.coordinates("#{@place.longitude},#{@place.latitude}")
    end
  end
end
