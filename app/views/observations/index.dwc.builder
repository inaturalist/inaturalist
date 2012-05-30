for observation in @observations
  xml.dwr :SimpleDarwinRecord do
    adapted_record = DarwinCore.adapt(observation, :view => self)
    DarwinCore::DARWIN_CORE_TERMS.each do |term, uri, default|
      term = "occurrenceID" if term == "id"
      value = adapted_record.send(term)
      next if value.blank?
      if uri =~ /purl/
        xml.dcterms term.to_sym, value
      else
        xml.dwc term.to_sym, value
      end
    end

    unless observation.photos.blank?
      observation.photos.each do |photo|
        EolMedia.adapt(photo)
        xml.eol :dataObject do
          EolMedia::TERMS.each do |term, uri, default|
            value = photo.send(term)
            next if value.blank?
            ns = uri.split('/')[-2]
            if uri =~ /purl/
              xml.dcterms term.to_sym, value
            elsif uri =~ /rs.tdwg.org\/ac/
              xml.ac term.to_sym, value
            elsif uri =~ /eol.org\/schema\/media/
              xml.media term.to_sym, value
            elsif uri =~ /ns.adobe.com\/xap/
              xml.xap term.to_sym, value
            elsif uri =~ /www.w3.org\/2003\/01\/geo/
              xml.geo term.to_sym, value
            elsif uri =~ /eol.org\/schema\/reference/
              xml.ref term.to_sym, value
            else
              xml.dwc term.to_sym, value
            end
          end
        end
      end
    end
  end
end
