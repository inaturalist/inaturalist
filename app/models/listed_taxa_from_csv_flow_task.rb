#encoding: utf-8
class ListedTaxaFromCsvFlowTask < FlowTask
  def run
    outputs.each(&:destroy)
    list_input = inputs.detect{|input| input.resource.is_a?(List)}
    file_input = inputs.detect{|input| input.file.exists?}
    row_handler = Proc.new do |row|
      # for some reason, even when you've coerced an entire string into UTF-8, 
      # CSV will still see individual rows in their original encoding, so they 
      # need to be encoded too
      row = row.map {|item| item.to_s.encode('UTF-8') }
      next if row.blank?
      taxon_name, description, occurrence_status, establishment_means = row
      next if taxon_name.blank?
      if list_input.resource.is_a?(CheckList)
        occurrence_status_level = ListedTaxon::OCCURRENCE_STATUS_LEVELS_BY_NAME[occurrence_status.to_s.downcase]
        establishment_means = ListedTaxon::ESTABLISHMENT_MEANS.include?(establishment_means.to_s.downcase) ? establishment_means.downcase : nil
      else
        occurrence_status_level = nil
        establishment_means = nil
      end
      taxon = Taxon.single_taxon_for_name(taxon_name)
      lt = ListedTaxon.new(
        :list => list_input.resource,
        :taxon => taxon,
        :description => description,
        :occurrence_status_level => occurrence_status_level,
        :establishment_means => establishment_means
      )
      lt.skip_sync_with_parent = true
      lt.force_update_cache_columns = true
      output = self.outputs.build
      extra = {:row => row, :taxon_id => taxon.try(:id)}
      if lt.save
        lt.update_primary
        output.resource = lt
      else
        extra[:error] = lt.errors.full_messages.to_sentence
      end
      output.extra = extra
      output.save
    end
    CSV.foreach(file_input.file.path, &row_handler)
  rescue ArgumentError => e
    raise e unless e.message =~ /invalid byte sequence in UTF-8/
    # if there's an encoding issue we'll try to load the entire file and adjust the encoding
    content = open(file_input.file.path).read
    utf_content = if content.encoding.name == 'UTF-8'
      # if Ruby thinks it's UTF-8 but it obviously isn't, we'll assume it's LATIN1
      content.force_encoding('ISO-8859-1')
      content.encode('UTF-8')
    else
      # otherwise we try to coerce it into UTF-8
      content.encode('UTF-8')
    end
    CSV.parse(content, &row_handler)
  end
end
