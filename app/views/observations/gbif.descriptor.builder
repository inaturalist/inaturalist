xml.instruct!
xml.archive :xmlns => "http://rs.tdwg.org/dwc/text/",
    :metadata => "metadata.eml.xml" do
  xml.core :encoding => "UTF-8", 
      :linesTerminatedBy => "\\n", 
      :fieldsTerminatedBy => ",",
      :fieldsEnclosedBy => '"',
      :ignoreHeaderLines => "1",
      :rowType => "http://rs.tdwg.org/dwc/terms/Occurrence" do
    xml.files do
      xml.location "observations.csv"
    end
    xml.id :index => 0
    DarwinCore::DARWIN_CORE_TERMS.each_with_index do |tuple, i|
      next if i == 0
      name, uri, default = tuple
      if default
        xml.field :index => i, :default => default, :term => uri
      else
        xml.field :index => i, :term => uri
      end
    end
  end
end