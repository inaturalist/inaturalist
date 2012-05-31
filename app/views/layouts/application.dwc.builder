xml.instruct!
xml.dwr :SimpleDarwinRecordSet, 
    "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
    "xsi:schemaLocation" => "http://rs.tdwg.org/dwc/xsd/simpledarwincore/  http://rs.tdwg.org/dwc/xsd/tdwg_dwc_simple.xsd",
    "xmlns:ac" => "http://rs.tdwg.org/ac/terms/",
    "xmlns:dcterms" => "http://purl.org/dc/terms/",
    "xmlns:dwc" => "http://rs.tdwg.org/dwc/terms/",
    "xmlns:dwr" => "http://rs.tdwg.org/dwc/xsd/simpledarwincore/",
    "xmlns:eol" => "http://www.eol.org/transfer/content/1.0",
    "xmlns:geo" => "http://www.w3.org/2003/01/geo/wgs84_pos#",
    "xmlns:media" => "http://eol.org/schema/media/",
    "xmlns:ref" => "http://eol.org/schema/reference/",
    "xmlns:xap" => "http://ns.adobe.com/xap/1.0/" do
  xml << yield
end
