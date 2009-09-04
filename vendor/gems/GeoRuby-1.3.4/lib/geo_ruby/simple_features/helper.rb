module GeoRuby
  module SimpleFeatures
    #indicates the presence of Z coordinates in EWKB strings
    Z_MASK=0x80000000
    #indicates the presence of M coordinates in EWKB strings.
    M_MASK=0x40000000
    #indicate the presence of a SRID in EWKB strings.
    SRID_MASK=0x20000000
    #GeoRSS namespace
    GEORSS_NS = "http://www.georss.org/georss"
    #GML Namespace
    GML_NS = "http://www.opengis.net/gml"
    #W3CGeo Namespace
    W3CGEO_NS = "http://www.w3.org/2003/01/geo/wgs84_pos#"
    #KML Namespace
    KML_NS = "http://earth.google.com/kml/2.1"
  end
end
