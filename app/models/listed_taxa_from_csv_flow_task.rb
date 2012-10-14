class ListedTaxaFromCsvFlowTask < FlowTask
  def run
    outputs.each(&:destroy)
    list_input = inputs.detect{|input| input.resource_type == "List"}
    file_input = inputs.detect{|input| input.file.exists?}
    CSV.foreach(file_input.file.path) do |row|
      next if row.blank?
      taxon_name, description, occurrence_status, establishment_means = row
      next if taxon_name.blank?
      if @list.is_a?(CheckList)
        occurrence_status_level = ListedTaxon::OCCURRENCE_STATUS_LEVELS_BY_NAME[occurrence_status]
        establishment_means = ListedTaxon::ESTABLISHMENT_MEANS.include?(establishment_means) ? establishment_means : nil
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
      extra = {:row => row}
      if lt.save
        output.resource = lt
      else
        extra[:error] = lt.errors.full_messages.to_sentence
      end
      output.extra = extra
      output.save
    end
  end
end
