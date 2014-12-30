class AncestryDenormalizer < Denormalizer

  def self.denormalize
    # looping through all taxa 10,000 at a time
    taxon_batch_size = 10000
    # insert the ancestors when we have 5,000 or more
    insert_maximum_values = 5000
    pending_values = [ ]
    each_taxon_batch_with_index(taxon_batch_size) do |taxa, index, total_batches|
      Taxon.transaction do
        # make sure we don't have any more entries than we have taxa. Trim any
        # taxa with ids lower than the current lowest and higher than the
        # current highest
        if index == 1
          psql.execute("DELETE FROM taxon_ancestors WHERE taxon_id < #{ taxa.first.id }")
        elsif index == total_batches
          psql.execute("DELETE FROM taxon_ancestors WHERE taxon_id > #{ taxa.last.id }")
        end
        # deleting this batch's data in a transaction. This will allow
        # this method to run while users are accessing the data. There
        # should not be any time (other than the first run) where a taxon
        # does not have ancestry information in this table
        psql.execute("DELETE FROM taxon_ancestors WHERE taxon_id BETWEEN #{ taxa.first.id } AND #{ taxa.last.id }")
        taxa.each do |taxon|
          # list every taxon as an ancestor of itself, so the roots
          # will at least be in this table if we want to INNER JOIN with it
          pending_values << [ taxon.id, taxon.id ]
          next if taxon.ancestry.blank?
          ancestor_ids = taxon.ancestry.split("/")
          pending_values += ancestor_ids.collect{ |a| [ taxon.id, a ] }
          pending_values = insert_values(pending_values, maximum_size: insert_maximum_values)
        end
      end
    end
    # insert any remaining ancestors
    insert_values(pending_values)
    psql.execute("VACUUM FULL VERBOSE ANALYZE taxon_ancestors") unless Rails.env.test?
  end

  def self.truncate
    psql.execute("TRUNCATE TABLE taxon_ancestors RESTART IDENTITY")
  end

  private

  def self.insert_values(values, options = {})
    options[:maximum_size] ||= 1
    if values.length >= options[:maximum_size]
      psql.execute("INSERT INTO taxon_ancestors VALUES " +
        values.collect{ |v| "(#{ v[0] },#{ v[1] })" }.join(",") )
      return [ ]
    end
    return values
  end

end
