#
# Creates default sources.
#
# Run this with script/runner!
#

unless ubio = Source.find_by_title('uBio')
  puts "Creating source for uBio..."
  ubio = Source.new(
    :in_text => 'uBio',
    :citation => 'uBio. <http://www.ubio.org/>.',
    :url => 'http://www.ubio.org',
    :title => 'uBio'
  )
  ubio.save
end

unless col = Source.find_by_title('Catalogue of Life')
  puts "Creating source for Catalogue of Life..."
  col = Source.new(
    :in_text => 'Bisby et al., 2007',
    :citation => 'FA Bisby, YR Roskov, MA Ruggiero, TM Orrell, LE Paglinawan, PW Brewer, N Bailly, J van Hertum, eds (2007). Species 2000 & ITIS Catalogue of Life: 2007 Annual Checklist Taxonomic Classification. CD-ROM; Species 2000: Reading, U.K.',
    :url => 'http://www.catalogueoflife.org',
    :title => 'Catalogue of Life'
  )
  col.save
end

unless inat = Source.find_by_title('iNaturalist')
  puts "Creating source for iNaturalist..."
  inat = Source.new(
    :in_text => 'iNaturalist',
    :citation => 'iNaturalist. <http://www.inaturalist.org/>.',
    :url => 'http://www.inaturalist.org',
    :title => 'iNaturalist'
  )
  inat.save
end

unless nzor = Source.find_by_title('New Zealand Organisms Register')
  puts "Creating source for NZOR..."
  nzor = Source.new(
    :in_text => 'New Zealand Organisms Register',
    :citation => 'NZOR. <http://data.nzor.org.nz/>.',
    :url => 'http://data.nzor.org.nz',
    :title => 'New Zealand Organisms Register'
  )
  nzor.save
end

%w(Birds Fungi Herpetofauna Invertebrates Mammals Plants Other).each do |kingdom|
  name = "NZBRN #{kingdom}"
  unless source = Source.find_by_title(name)
    puts "Creating source for #{name}..."
    source = Source.new(
      :in_text => name,
      :citation => "#{name}. <http://www.nzbrn.org.nz/#{kingdom.downcase}/>.",
      :url => "http://www.nzbrn.org.nz/#{kingdom.downcase}/",
      :title => name
    )
    source.save
  end
end
