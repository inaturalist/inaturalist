for observation in @observations
  xml.dwr :SimpleDarwinRecord do
    Observation::DARWIN_CORE_TERMS.each do |term, uri, default|
      term = "occurrenceID" if term == "id"
      value = observation.send(term)
      next if value.blank?
      if uri =~ /purl/
        xml.dcterms term.to_sym, value
      else
        xml.dwc term.to_sym, value
      end
    end
  end
end