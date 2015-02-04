iconic_taxa_by_name = Taxon.iconic_taxa.index_by(&:name)
mapnik_xml_path = File.join(Rails.root, 'config/observations.mapnik.xml')
icon_path = File.join(Rails.root, 'app/assets/mapMarkers')
vrt_xml_path = File.join(Rails.root, "config/observations_#{Rails.env}.ogr.vrt")
db_config = YAML.load(File.open("#{Rails.root}/config/database.yml"))[Rails.env]
db_connection_string = "#{ActiveRecord::Base.connection.adapter_name.upcase}:"
# db_connection_string += db_config[Rails.env].map{|k,v| "#{k}=#{v}"}.join(',')
db_connection_string += "#{db_config['database']}"
db_connection_string += ",user=#{db_config['username']}" if db_config['username']
db_connection_string += ",host=#{db_config['host']}" if db_config['host']
db_connection_string += ",password=#{db_config['password']}" if db_config['password']
db_connection_string += ",port=#{db_config['port']}" if db_config['port']
db_connection_string += ",tables=#{Observation.table_name}"

mapnik_xml = <<XML
<Map srs="+proj=latlong +datum=WGS84">
  <Style name="observationsStyle">
    <Rule>
      <Filter>[iconic_taxon_id] = #{iconic_taxa_by_name['Plantae'].id}</Filter>
      <PointSymbolizer file="#{File.join(icon_path, 'mm_8_stemless_iNatGreen.png')}" type="png" width="8" height="8" />
    </Rule>
    <Rule>
      <Filter>#{%w"Animalia Aves Mammalia Actinopterygii Amphibia Reptilia".map {|name| "[iconic_taxon_id] = #{iconic_taxa_by_name[name].id}"}.join(' or ')}</Filter>
      <PointSymbolizer file="#{File.join(icon_path, 'mm_8_stemless_DodgerBlue.png')}" type="png" width="8" height="8" />
    </Rule>
    <Rule>
      <Filter>#{%w"Insecta Arachnida Mollusca".map {|name| "[iconic_taxon_id] = #{iconic_taxa_by_name[name].id}"}.join(' or ')}</Filter>
      <PointSymbolizer file="#{File.join(icon_path, 'mm_8_stemless_OrangeRed.png')}" type="png" width="8" height="8" />
    </Rule>
    <Rule>
      <Filter>[iconic_taxon_id] = #{iconic_taxa_by_name['Fungi'].id}</Filter>
      <PointSymbolizer file="#{File.join(icon_path, 'mm_8_stemless_DeepPink.png')}" type="png" width="8" height="8" />
    </Rule>
    <Rule>
      <ElseFilter/>
      <PointSymbolizer file="#{File.join(icon_path, 'mm_8_stemless_unknown.png')}" type="png" width="8" height="8" />
    </Rule>
  </Style>

  <Layer name="observationsLayer" srs="+proj=latlong +datum=WGS84">
    <StyleName>observationsStyle</StyleName>
    <Datasource>
      <Parameter name="type">ogr</Parameter>
      <Parameter name="file">#{vrt_xml_path}</Parameter>
      <Parameter name="layer">observations</Parameter>
    </Datasource>
  </Layer>
</Map>
XML

file = File.new(mapnik_xml_path, 'w+')
file.write(mapnik_xml)
file.close

vrt_xml = <<XML
<OGRVRTDataSource>
    <OGRVRTLayer name="observations">
        <SrcDataSource>#{db_connection_string}</SrcDataSource> 
        <SrcSQL>SELECT id, latitude, longitude, iconic_taxon_id FROM #{Observation.table_name} ORDER BY id DESC</SrcSQL> 
        <GeometryType>wkbPoint</GeometryType>
        <GeometryField encoding="PointFromColumns" x="longitude" y="latitude"/> 
    </OGRVRTLayer>
</OGRVRTDataSource>
XML

file = File.new(vrt_xml_path, 'w+')
file.write(vrt_xml)
file.close

puts "Created #{mapnik_xml_path}"
puts "Created #{vrt_xml_path}"
puts "You can move these files to wherever your tile server is expecting "
puts "them, but make sure to change the path to the VRT within the Mapnik "
puts "XML."
