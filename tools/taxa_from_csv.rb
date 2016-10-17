require 'rubygems'
require 'trollop'
require 'csv'

opts = Trollop::options do
    banner <<-EOS
Import taxa from a list of names in CSV following the format

scientific name,iconic taxon name,common name 1, common name 1 lexicon, common name 2, common name 2 lexicon

Only the scientific name is required. So an example row might be

Homo sapiens,Mammalia,Human,English,Humano,Spanish

but

Homo sapiens
Vulpes vulpes

would also work

Usage:

  rails runner tools/taxa_from_csv.rb [OPTIONS] path/to/file.csv

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
end

start = Time.now

OPTS = opts

csv_path = ARGV[0]
Trollop::DIE unless csv_path && File.exist?(csv_path)

def save_common_names(taxon, common_names)
  common_names.in_groups_of(2) do |name,lexicon|
    next if name.blank?
    name = name.split(/[,;]/).first
    tn = TaxonName.new(:taxon => taxon, :name => name, :lexicon => lexicon, :is_valid => true)
    if tn.save
      puts "\tCreated #{tn}"
    else
      puts "\tFailed to create #{tn}: #{tn.errors.full_messages.to_sentence}"
    end
  end
end

num_created = num_existing = 0
errors = []
CSV.foreach(csv_path) do |row|
  sciname, iconic_taxon_name, *common_names = row
  puts sciname
  next unless sciname
  existing = Taxon.active.find_by_name(sciname)
  existing ||= Taxon.find_by_name(sciname)
  existing ||= Taxon.single_taxon_for_name(sciname)
  if existing
    num_existing += 1
    puts "\tFound #{existing}"
    save_common_names(existing, common_names)
    next
  end

  taxon = begin
    Taxon.import(sciname)
  rescue NameProviderError
    nil
  end
  unless taxon
    errors << [sciname, "couldn't import a taxon"]
    puts "\t"+errors.last.last
    next
  end
  puts "\tSaved #{taxon}"
  num_created += 1
  save_common_names(taxon, common_names)

  begin
    taxon.graft
  rescue RatatoskGraftError => e
    errors << [sciname, "failed to graft"]
    puts "\t"+errors.last.last
    next
  end
  puts "\tGrafted to #{taxon.parent_id}"

end

puts "Finished in #{Time.now - start} s, #{num_created} created, #{num_existing} existing, errors:"
unless errors.blank?
  puts "Errors:"
  errors.group_by(&:last).each do |grouped_error, grouped_errors|
    puts "\t#{grouped_error}"
    grouped_errors.each do |name, error|
      puts "\t\t#{name}"
    end
  end
end
