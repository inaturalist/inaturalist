#encoding: utf-8

require "rubygems"
require "optimist"
require "csv"

opts = Optimist::options do
    banner <<-EOS
Import taxa from a list of names in CSV following the format

scientific name,common name 1, common name 1 lexicon, common name 2, common name 2 lexicon

Only the scientific name is required. So an example row might be

  Homo sapiens,Human,English,Humano,Spanish

but this would also work

  Homo sapiens
  Vulpes vulpes

This script can also be used to import common names without creating taxa. Note
that it will not import common names that are duplicated within the file or
duplicated within the lexicon, e.g. if there's already a taxon named "puppy" in
English, any rows for that name in that lexicon will be ignored.

Usage:

  rails runner tools/taxa_from_csv.rb [OPTIONS] path/to/file.csv

Examples:
  
  # Import common names from a pre-existing source, attributing a specific user,
  # without adding taxa
  be rails r tools/taxa_from_csv.rb -d -c --skip-check-lists -s 16299 -u 1 -p 7016 --lexicon-first ~/names.csv > ~/names.log

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :skip_creation, "Add names and places, but don't create taxa", type: :boolean, short: "-c"
  opt :skip_check_lists, "Don't add taxa to checklists", type: :boolean
  opt :place_id, "Place whose checklist these taxa should be added to", type: :integer, short: "-p"
  opt :user_id, "User ID of user who is adding these names", type: :integer, short: "-u"
  opt :source_id, "Source ID of source to use for these names these names", type: :integer, short: "-s"
  opt :lexicon_first, "Allow file to be of format sciname, lexicon, comname", type: :boolean
  opt :lexicon, "Lexicon that will override the lexicon in the file", type: :string, short: "-l"
end

start = Time.now

OPTS = opts

csv_path = ARGV[0]
unless csv_path && File.exist?(csv_path)
  Optimist::die "CSV does not exist: #{csv_path}"
end

if !opts.place_id.blank?
  if @place = Place.find( opts.place_id )
    puts "Found place: #{@place}"
  else
    Optimist::die "Couldn't find place: #{OPTS.place_id}"
  end
end

if !opts.user_id.blank?
  if @user = User.find( opts.user_id )
    puts "Found user: #{@user}"
  else
    Optimist::die "Couldn't find user: #{OPTS.user_id}"
  end
end

if !opts.source_id.blank?
  if @source = Source.find( opts.source_id )
    puts "Found source: #{@source}"
  else
    Optimist::DIE "Couldn't find source: #{OPTS.source_id}"
  end
end

@errors = []
@names_created = @names_existing = @name_errors = @names_skipped = 0
@ptn_created = @ptn_existing = @ptn_errors = 0
@listed_taxa_created = 0
@encountered_names = {}

def save_common_names(taxon, common_names)
  common_names.in_groups_of(2) do |c1, c2|
    if OPTS.lexicon_first
      lexicon = c1
      name = c2
    else
      lexicon = c2
      name = c1
    end
    next if name.blank?
    name = name.split(/[,;]/).first.strip
    # Disallow duplicates within the same file
    next if @encountered_names[name]
    @encountered_names[name] = true
    lexicon = OPTS.lexicon || lexicon
    # Disallow duplicates within a lexicon
    if TaxonName.where( lexicon: lexicon, name: name ).exists?
      puts "\tName already exists in this lexicon"
      @names_skipped += 1
      next
    end
    if tn = taxon.taxon_names.where( name: name, lexicon: lexicon ).first
      @names_existing += 1
    else
      tn = TaxonName.new(
        taxon: taxon,
        name: name,
        lexicon: lexicon,
        creator: @user,
        source: @source
      )
      begin
        if tn.save
          puts "\tCreated #{tn}"
          @names_created += 1
        else
          puts "\tFailed to create #{tn}: #{tn.errors.full_messages.to_sentence}"
          unless tn.errors.full_messages.to_sentence =~ /already exists/
            @errors << [taxon.name, "failed common name: #{tn.errors.full_messages.to_sentence}"]
          end
        end
      rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique
        puts "\tFailed to create #{tn}: already added"
      end
    end
    if tn && tn.persisted? && @place
      if ptn = tn.place_taxon_names.where( place_id: @place.id ).first
        @ptn_existing += 1
      else
        ptn = tn.place_taxon_names.build( place: @place )
        if ptn.save
          puts "\tCreated #{ptn}"
          @ptn_created += 1
        else
          puts "\tFailed to create place taxon name: #{ptn.errors.full_messages.to_sentence}"
          @errors << [taxon.name, "failed place taxon name: #{ptn.errors.full_messages.to_sentence}"]
        end
      end
    end
  end
rescue Faraday::ConnectionFailed
  sleep 5
  retry
end

def add_to_place( taxon, place )
  lt = place.check_list.listed_taxa.build( taxon: taxon )
  if lt.save
    puts "\tCreated #{lt}"
    @listed_taxa_created += 1
  else
    puts "\tFailed to add to #{place.name}: #{lt.errors.full_messages.to_sentence}"
    unless lt.errors.full_messages.to_sentence =~ /already/
      @errors << [taxon.name, "failed to add to place"]
    end
  end
end

num_created = num_existing = 0
not_created = []

CSV.foreach( csv_path, skip_blanks: true ) do |row|
  sciname, *common_names = row
  puts row.join( " | " )
  next unless sciname

  unless taxon = Taxon.single_taxon_for_name( sciname )
    candidates = Taxon.where( name: sciname )
    if candidates.active.count > 1
      @errors << [sciname, "multiple active taxa"]
      next
    end

    if candidates.inactive.count > 1
      @errors << [sciname, "multiple inactive taxa"]
      next
    end

    if inactive_candidate = candidates.inactive.first
      unless taxon = inactive_candidate.current_synonymous_taxon
        @errors << [sciname, "inactive taxon with no single active synonym"]
        next
      end
    end
  end

  if taxon
    num_existing += 1
    puts "\tFound #{taxon}"
    save_common_names(taxon, common_names)
    add_to_place( taxon, @place ) if @place && !OPTS.skip_check_lists
    next
  end

  if opts.skip_creation
    not_created << sciname
    next
  end

  taxon = begin
    Taxon.import(sciname)
  rescue NameProviderError
    nil
  end
  unless taxon
    @errors << [sciname, "couldn't import a taxon"]
    puts "\t"+@errors.last.last
    next
  end
  puts "\tCreated #{taxon}"
  num_created += 1
  save_common_names(taxon, common_names)
  add_to_place( taxon, @place) if @place && !OPTS.skip_check_lists

  begin
    taxon.graft
  rescue RatatoskGraftError => e
    @errors << [sciname, "failed to graft"]
    puts "\t"+@errors.last.last
    next
  end
  puts "\tGrafted to #{taxon.parent_id}"

end

puts

unless not_created.blank?
  puts
  puts "Not created:"
  puts
  puts not_created.join( "\n" )
  puts
end

unless @errors.blank?
  puts
  puts "Errors:"
  puts
  @errors.group_by(&:last).each do |grouped_error, grouped_errors|
    puts "\t#{grouped_error}"
    grouped_errors.each do |name, error|
      puts "\t\t#{name}"
    end
  end
end

puts
puts "Finished in #{Time.now - start} s"
puts "#{num_created} taxa created"
puts "#{not_created.size} taxa not created"
puts "#{num_existing} taxa existing"
puts "#{@names_created} names created"
puts "#{@names_existing} names existing"
puts "#{@names_skipped} names skipped b/c they already exist for other taxa"
puts "#{@ptn_created} names added to place"
puts "#{@ptn_existing} already added to place"
puts "#{@listed_taxa_created} listed taxa created"
puts
