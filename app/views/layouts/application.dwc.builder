xml.instruct!
xml.dwr :SimpleDarwinRecordSet, 
    "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
    "xsi:schemaLocation" => "http://rs.tdwg.org/dwc/xsd/simpledarwincore/  http://rs.tdwg.org/dwc/xsd/tdwg_dwc_simple.xsd",
    "xmlns:dcterms" => "http://purl.org/dc/terms/",
    "xmlns:dwc" => "http://rs.tdwg.org/dwc/terms/",
    "xmlns:dwr" => "http://rs.tdwg.org/dwc/xsd/simpledarwincore/" do
  xml << yield
end