class AncestryDenormalizer < Denormalizer

  def self.denormalize
    # create a new working table to populate which will be swapped with the primary table at the end
    psql.execute( "DROP TABLE IF EXISTS taxon_ancestors_working" )
    psql.execute( "CREATE TABLE taxon_ancestors_working (LIKE taxon_ancestors INCLUDING ALL)" )
    # looping through all taxa 10,000 at a time
    taxon_batch_size = 10000
    # insert the ancestors when we have 5,000 or more
    insert_maximum_values = 5000
    pending_values = [ ]
    each_taxon_batch_with_index( taxon_batch_size ) do |taxa, index, total_batches|
      taxa.each do |taxon|
        # list every taxon as an ancestor of itself, so the roots
        # will at least be in this table if we want to INNER JOIN with it
        pending_values << [ taxon.id, taxon.id ]
        next if taxon.ancestry.blank?
        ancestor_ids = taxon.ancestry.split("/")
        pending_values += ancestor_ids.collect{ |a| [ taxon.id, a ] }
        pending_values = insert_values( pending_values, maximum_size: insert_maximum_values )
      end
    end
    # insert any remaining ancestors
    insert_values( pending_values )
    psql.execute( "VACUUM FULL VERBOSE ANALYZE taxon_ancestors_working" ) unless Rails.env.test?
    Taxon.transaction do
      # in a transation, swap the working and primary tables and delete the old primary
      psql.execute( "ALTER TABLE taxon_ancestors RENAME TO taxon_ancestors_previous" )
      psql.execute( "ALTER TABLE taxon_ancestors_working RENAME TO taxon_ancestors" )
      psql.execute( "DROP TABLE taxon_ancestors_previous" )
    end
  end

  def self.truncate
    psql.execute("TRUNCATE TABLE taxon_ancestors RESTART IDENTITY")
  end

  private

  def self.insert_values(values, options = {})
    options[:maximum_size] ||= 1
    if values.length >= options[:maximum_size]
      psql.execute("INSERT INTO taxon_ancestors_working VALUES " +
        values.collect{ |v| "(#{ v[0] },#{ v[1] })" }.join(",") )
      return [ ]
    end
    return values
  end

end
