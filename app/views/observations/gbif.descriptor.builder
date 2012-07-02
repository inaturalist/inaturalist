if @core == "taxon"
  core_row_type = "http://rs.tdwg.org/dwc/terms/Taxon"
  core_file_location = "taxa.csv"
  core_terms = DarwinCore::Taxon::TERMS
else
  core_row_type = "http://rs.tdwg.org/dwc/terms/Occurrence"
  core_file_location = "observations.csv"
  core_terms = DarwinCore::Occurrence::TERMS
end
xml.instruct!
xml.archive :xmlns => "http://rs.tdwg.org/dwc/text/",
    :metadata => "metadata.eml.xml" do
  xml.core :encoding => "UTF-8", 
      :linesTerminatedBy => "\\n", 
      :fieldsTerminatedBy => ",",
      :fieldsEnclosedBy => '"',
      :ignoreHeaderLines => "1",
      :rowType => core_row_type do
    xml.files do
      xml.location core_file_location
    end
    xml.id :index => 0
    core_terms.each_with_index do |tuple, i|
      # next if i == 0
      name, uri, default = tuple
      if default
        xml.field :index => i, :default => default, :term => uri
      else
        xml.field :index => i, :term => uri
      end
    end
  end
  
  if @extensions
    @extensions.each do |ext|
      ext_file_location = ext[:file_location]
      ext_terms = ext[:terms]
      ext_row_type = ext[:row_type]
      xml.extension :encoding => "UTF-8", 
          :linesTerminatedBy => "\\n", 
          :fieldsTerminatedBy => ",",
          :fieldsEnclosedBy => '"',
          :ignoreHeaderLines => "1",
          :rowType => ext_row_type do
        xml.files do
          xml.location ext_file_location
        end
        xml.coreid :index => 0
        ext_terms.each_with_index do |tuple, i|
          # next if i == 0
          name, uri, default = tuple
          if default
            xml.field :index => i, :default => default, :term => uri
          else
            xml.field :index => i, :term => uri
          end
        end
      end
    end
  end
end
