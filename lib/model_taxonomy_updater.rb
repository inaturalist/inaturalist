# frozen_string_literal: true

class ModelTaxonomyUpdater
  attr_reader :start_time,
    :model_taxonomy_path,
    :taxonomy_generated_at,
    :model_taxa,
    :current_synonymous_taxa,
    :final_output_dir,
    :tmpdir

  def initialize( model_taxonomy_path, taxonomy_generated_at, final_output_dir = nil )
    @start_time = Time.now.to_i
    @model_taxonomy_path = model_taxonomy_path
    @taxonomy_generated_at = taxonomy_generated_at
    @final_output_dir = final_output_dir
    @tmpdir = File.join( Dir.tmpdir, "retro-taxa-#{@start_time}" )
  end

  def process
    make_tmpdir
    load_taxonomy
    lookup_current_synonymous_taxa
    write_synonym_mappings
    fetch_new_taxonomy_data
    write_taxonomy
    copy_output_files
  end

  def make_tmpdir
    FileUtils.mkdir( @tmpdir )
  end

  def copy_output_files
    return unless @final_output_dir

    FileUtils.mv( Dir.glob( File.join( @tmpdir, "*.csv" ) ), @final_output_dir )
  end

  def load_taxonomy
    puts "[DEBUG] Loading taxonomy..."
    @model_taxa = {}
    CSV.foreach(
      @model_taxonomy_path,
      headers: true,
      quote_char: nil
    ) do | row |
      @model_taxa[row["taxon_id"].to_i] = row
    end
  end

  def leaf_taxon_ids
    @model_taxa.
      select {| _index, t | t["leaf_class_id"] }.
      map {| _index, t | t["taxon_id"].to_i }.
      sort
  end

  def lookup_current_synonymous_taxa
    puts "[DEBUG] Looking up synonyms..."
    @current_synonymous_taxa = {}
    leaf_taxon_ids.in_groups_of( 200, false ) do | group_ids |
      Taxon.
        where( id: group_ids ).
        includes( :taxon_changes, :taxon_change_taxa ).each do | taxon |
        next unless taxon.taxon_changes_count.positive?

        taxon.current_synonymous_taxa( committed_after: @taxonomy_generated_at ).each do | synonym |
          @current_synonymous_taxa[taxon.id] ||= []
          @current_synonymous_taxa[taxon.id].push( synonym )
        end
        if !taxon.is_active? && !@current_synonymous_taxa[taxon.id]
          @current_synonymous_taxa[taxon.id] = []
        end
      end
    end
  end

  def write_synonym_mappings
    puts "[DEBUG] Writing synonyms..."
    output_file_path = File.join( @tmpdir, "synonyms.csv" )
    output_file = File.open( output_file_path, "w" )
    columns = %w(
      model_taxon_id
      parent_taxon_id
      taxon_id
      rank_level
      name
    )
    output_file.write( "#{columns.join( ',' )}\n" )

    @current_synonymous_taxa.map do | taxon_id, synonyms |
      if synonyms.empty?
        output_file.write( "#{taxon_id},,,,\n" )
      else
        synonyms.each do | synonym |
          row = {
            model_taxon_id: taxon_id,
            parent_taxon_id: synonym.parent_id,
            taxon_id: synonym.id,
            rank_level: synonym.rank_level,
            name: synonym.name.tr( ",", "" )
          }
          output_file.write( "#{row.values.join( ',' )}\n" )
        end
      end
    end

    output_file.close
    puts "[DEBUG] Output synonyms saved to #{output_file_path}"
  end

  def fetch_new_taxonomy_data
    puts "[DEBUG] Fetching updated taxonomy..."
    synonym_ids = @current_synonymous_taxa.values.flatten.uniq.map( &:id )
    model_taxon_ids_to_lookup = synonym_ids + leaf_taxon_ids

    all_taxon_and_ancestor_ids = {}
    model_taxon_ids_to_lookup.in_groups_of( 1000, false ) do | group_ids |
      Taxon.where( id: group_ids ).
        select( :id, :ancestry ).each do | taxon |
        taxon.self_and_ancestor_ids.each do | id |
          all_taxon_and_ancestor_ids[id] = true
        end
      end
    end

    @taxon_metadata_from_db = {}
    @taxon_children = {}
    all_taxon_and_ancestor_ids.keys.in_groups_of( 1000, false ) do | group_ids |
      Taxon.where( id: group_ids ).
        order( observations_count: :desc ).
        pluck( :id, :ancestry, :rank_level, :name ).each do | row |
        id, ancestry, rank_level, name = row
        @taxon_metadata_from_db[id] ||= {}
        @taxon_metadata_from_db[id][:rank_level] = rank_level
        @taxon_metadata_from_db[id][:name] = name
        last_ancestor_id = 0
        ancestors = ancestry.blank? ? [] : ancestry.split( "/" ).map( &:to_i )
        ancestors << id
        ancestors.each do | ancestor_id |
          if @taxon_metadata_from_db[ancestor_id]&.key?( :parent_id )
            existing_parent_id = @taxon_metadata_from_db[ancestor_id][:parent_id]
            if existing_parent_id != last_ancestor_id
              puts "Ancestry mismatch: #{ancestor_id} has parents " \
                "[#{last_ancestor_id} #{existing_parent_id}] in ancestry of #{id}"
            end
          end
          @taxon_children[last_ancestor_id] ||= {}
          @taxon_children[last_ancestor_id][ancestor_id] = true
          @taxon_metadata_from_db[ancestor_id] ||= {}
          @taxon_metadata_from_db[ancestor_id][:parent_id] = last_ancestor_id
          last_ancestor_id = ancestor_id
        end
      end
    end
    nil
  end

  def write_taxonomy
    puts "[DEBUG] Writing taxonomy..."
    output_taxonomy_file_path = File.join( @tmpdir, "synonym_taxonomy.csv" )
    @output_taxonomy_file = File.open( output_taxonomy_file_path, "w" )
    columns = %w(
      parent_taxon_id
      taxon_id
      rank_level
      leaf_class_id
      iconic_class_id
      spatial_class_id
      name
    )
    @output_taxonomy_file.write( "#{columns.join( ',' )}\n" )
    write_all_taxa
    @output_taxonomy_file.close
    puts "[DEBUG] Output taxonomy saved to #{output_taxonomy_file_path}"
  end

  def write_all_taxa( taxon_id = Taxon::LIFE.id )
    child_ids = @taxon_children[taxon_id].keys.sort
    child_ids.each do | child_id |
      taxon = @taxon_metadata_from_db[child_id]
      model_taxon = @model_taxa[child_id]
      unless taxon[:name]
        raise "Unknown taxon #{child_id}"
      end

      row = {
        parent_taxon_id: taxon[:parent_id] == Taxon::LIFE.id ? "" : taxon[:parent_id],
        taxon_id: child_id,
        rank_level: taxon[:rank_level] == taxon[:rank_level].to_i ? taxon[:rank_level].to_i : taxon[:rank_level],
        leaf_class_id: ( model_taxon && model_taxon["leaf_class_id"] ) || "",
        iconic_class_id: ( model_taxon && model_taxon["iconic_class_id"] ) || "",
        spatial_class_id: ( model_taxon && model_taxon["spatial_class_id"] ) || "",
        name: taxon[:name]
      }
      @output_taxonomy_file.write( "#{row.values.join( ',' )}\n" )
      if @taxon_children[child_id]
        write_all_taxa( child_id )
      end
    end
    nil
  end

  def inspect
    "#<ModelTaxonomyUpdater @model_taxonomy_path=\"#{model_taxonomy_path}, ...\">"
  end
end
