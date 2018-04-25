require 'rubygems'
require 'trollop'
require 'csv'

opts = Trollop::options do
    banner <<-EOS
Import taxa from a list of names in CSV following the format

scientific name,iconic taxon name,common name 1, common name 1 lexicon, common name 2, common name 2 lexicon

Only the scientific name is required. So an example row might be

Homo sapiens,Human,English,Humano,Spanish

but

Homo sapiens
Vulpes vulpes

would also work

Usage:

  rails runner tools/taxa_from_csv.rb [OPTIONS] path/to/file.csv

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :skip_creation, "Add names and places, but don't create taxa", type: :boolean, short: "-c"
  opt :place_id, "Place whose checklist these taxa should be added to", type: :integer, short: "-p"
end

start = Time.now

OPTS = opts

csv_path = ARGV[0]
Trollop::DIE unless csv_path && File.exist?(csv_path)
if opts.place_id && @place = Place.find( opts.place_id )
  puts "Found place: #{@place}"
end

@errors = []

def save_common_names(taxon, common_names)
  common_names.in_groups_of(2) do |name,lexicon|
    next if name.blank?
    name = name.split(/[,;]/).first
    tn = TaxonName.new(:taxon => taxon, :name => name, :lexicon => lexicon, :is_valid => true)
    begin
      if tn.save
        puts "\tCreated #{tn}"
      else
        puts "\tFailed to create #{tn}: #{tn.errors.full_messages.to_sentence}"
        unless tn.errors.full_messages.to_sentence =~ /already exists/
          @errors << [taxon.name, "failed common name"]
        end
      end
    rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique
      puts "\tFailed to create #{tn}: already added"
    end
  end
end

def add_to_place( taxon, place )
  lt = place.check_list.listed_taxa.build( taxon: taxon )
  if lt.save
    puts "\tCreated #{lt}"
  else
    puts "\tFailed to add to #{place.name}: #{lt.errors.full_messages.to_sentence}"
    unless lt.errors.full_messages.to_sentence =~ /already/
      @errors << [taxon.name, "failed to add to place"]
    end
  end
end

num_created = num_existing = 0
not_created = []

CSV.foreach(csv_path) do |row|
  sciname, *common_names = row
  puts sciname
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
    add_to_place( taxon, @place ) if @place
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
  add_to_place( taxon, @place) if @place

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
puts "Finished in #{Time.now - start} s, #{num_created} created, #{not_created.size} not created, #{num_existing} existing"
puts
