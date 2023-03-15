# frozen_string_literal: true

require "rubygems"
require "optimist"

@opts = Optimist.options do
  banner <<~HELP
    Clean up lexicons, try to remove synonyms, apply Place Taxon Names to regional
    lexicons.

    Usage:

      rails runner tools/clean_taxon_names.rb

    where [options] are:
  HELP
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :dry, "Dry run, don't make changes, just report", type: :boolean
end

start = Time.now
deleted = []
updated = []
created_ptns = []
invalid_ptns = []
taxon_ids_to_index = []

puts
puts "== REGIONALIZING LEXICONS =="
puts
puts <<~TXT
  Sometimes people add separate lexicons for a language in a region that should
  be handled with PlaceTaxonNames instead, so this will try and convert those
  and delete names that are no longer valid after being updated
  (generally because a correct version of the name already exists)
TXT
language_place_lexicons = [
  { wrong_lexicon: "Australian", right_lexicon: TaxonName::ENGLISH, country_name: "Australia" },
  { wrong_lexicon: "Egyptian Arabic", right_lexicon: TaxonName::ARABIC, country_name: "Egypt" },
  { wrong_lexicon: "English(india)", right_lexicon: TaxonName::ENGLISH, country_name: "India" },
  { wrong_lexicon: "Español (Argentina)", right_lexicon: TaxonName::SPANISH, country_name: "Argentina" },
  { wrong_lexicon: "Español (Chile)", right_lexicon: TaxonName::SPANISH, country_name: "Chile" },
  { wrong_lexicon: "Español (Costa Rica)", right_lexicon: TaxonName::SPANISH, country_name: "Costa Rica" },
  { wrong_lexicon: "Español (Ecuador)", right_lexicon: TaxonName::SPANISH, country_name: "Ecuador" },
  { wrong_lexicon: "Español (Uruguay)", right_lexicon: TaxonName::SPANISH, country_name: "Uruguay" },
  { wrong_lexicon: "Español Chileno", right_lexicon: TaxonName::SPANISH, country_name: "Chile" },
  { wrong_lexicon: "Español Perú", right_lexicon: TaxonName::SPANISH, country_name: "Peru" },
  { wrong_lexicon: "Moroccan Arabic", right_lexicon: TaxonName::ARABIC, country_name: "Morocco" },
  { wrong_lexicon: "Português (Brasil)", right_lexicon: TaxonName::PORTUGUESE, country_name: "Brazil" },
  { wrong_lexicon: "Spanish (Chile)", right_lexicon: TaxonName::SPANISH, country_name: "Chile" },
  { wrong_lexicon: "Spanish (Peru)", right_lexicon: TaxonName::SPANISH, country_name: "Peru" },
  { wrong_lexicon: "Spanish (Perú)", right_lexicon: TaxonName::SPANISH, country_name: "Peru" }
]
language_place_lexicons.each do | x |
  puts "Changing #{x[:wrong_lexicon]} to #{x[:right_lexicon]} and assigning to #{x[:country_name]}"
  unless ( country = Place.where( name: x[:country_name], admin_level: Place::COUNTRY_LEVEL ).first )
    puts "Couldn't find country, skipping"
    next
  end
  TaxonName.where( lexicon: x[:wrong_lexicon] ).includes( :taxon ).find_each do | tn |
    print "."
    tn.lexicon = x[:right_lexicon]
    tn.skip_indexing = true
    tn.taxon.skip_indexing
    taxon_ids_to_index << tn.taxon_id
    if tn.valid?
      tn.save unless @opts.dry
      updated << tn
      ptn = tn.place_taxon_names.build( place: country )
      if ptn.valid?
        ptn.save unless @opts.dry
        created_ptns << ptn
      else
        puts "Failed to save #{ptn}, errors: #{ptn.errors.full_messages.to_sentence}" if @opts.debug
        invalid_ptns << ptn
      end
    else
      puts "Failed to save #{tn}, errors: #{tn.errors.full_messages.to_sentence}" if @opts.debug
      tn.destroy unless @opts.dry
      deleted << tn
    end
  end
  puts
end

puts
puts "== SYNONYMIZING LEXICONS =="
puts
puts <<~TXT
  We get A LOT of lexicons that are variations of existing lexicons, so this
  tries to make some of the more common ones conform to conventional versions.
TXT
synonyms = {
  "AOU 4-Letter Codes" => ["Aou 4 Letter Codes"],
  "Bunun" => ["Bunun (Taiwan)"], # this is regional but doesn't really need to be since this is only spoken in Taiwan
  TaxonName::BELARUSIAN => ["Беларуская"],
  TaxonName::CATALAN => ["Català"],
  # Not sure we should do this, but there are rather a lot of "Mandarin Chinese"
  # names that are not being shown to anyone with a Chinese locale preference
  # TaxonName::CHINESE_SIMPLIFIED => ["Mandarin Chinese"],
  TaxonName::CHINESE_TRADITIONAL => ["Chinese Traditional"],
  "Choctaw" => ["Chochtaw"],
  "Cree" => ["American Indian (Cree)"],
  TaxonName::CREOLE_PORTUGUESE => ["Creole (Portuguese)"],
  TaxonName::ENGLISH => ["Simple English"],
  TaxonName::FRENCH => ["Français"],
  TaxonName::GERMAN => ["Deutsch"],
  "Greek" => ["Greek (Modern)", "Modern Greek (1453 )"],
  "Gujarati" => ["Gujarātī. ગુજરાતી,", "ગુજરાતી"],
  "Hokkien" => ["臺灣閩南語"],
  TaxonName::ITALIAN => ["Italiano"],
  "Indonesian" => ["Bahasa Indonesia"],
  "Irish" => ["Irish Gaelic"],
  TaxonName::JAPANESE => ["Japanese (Kanji)"],
  "Ju|'hoan" => ["Juǀ’hoan"],
  "Malay" => ["Malay (Individual Language)", "Malayan"],
  "Nahuatl" => ["Náhuatl"],
  TaxonName::NORWEGIAN => ["Norwegian Bokmal", "Norsk"],
  "Oshikwanyama" => ["Oshi Kwanyama"],
  TaxonName::PORTUGUESE => ["Português"],
  TaxonName::RUSSIAN => ["Русски", "Русский"],
  TaxonName::SCIENTIFIC_NAMES => [
    "Nombres Científicos",
    "Nomes Científicos",
    "Nomi Scientifici",
    "Noms Scientifiques",
    "Scientific Name",
    "Tieteelliset Nimet",
    "Videnskabelige Navne",
    "Wetenschappelijke Namen",
    "Wissenschaftliche Namen",
    "Научные названия",
    "学名",
    "學名"
  ],
  TaxonName::SETSWANA => ["Tswana"],
  TaxonName::SLOVAK => ["Slovakian"],
  TaxonName::SLOVENIAN => ["Slovene"],
  "Sotho (Northern)" => ["Northern Sotho", "Sotho ( Northern)"],
  TaxonName::SPANISH => ["Español"],
  "Swahili" => ["Swahili (Individual Language)", "Kiswahili"],
  TaxonName::UKRAINIAN => ["український"],
  "Uyghur" => ["Uyghurche / ئۇيغۇرچە", "Uyghurche", "ئۇيغۇرچە"],
  TaxonName::WARAY_WARAY => ["Waray", "Waray (Philippines)"],
  "Yaqui" => ["yaqui"]
}

synonyms.each do | lexicon, syns |
  puts "#{lexicon} synonyms: #{syns.join( ', ' )}"
  TaxonName.where( lexicon: syns ).includes( :taxon ).find_each do | tn |
    print "."
    tn.lexicon = lexicon
    tn.skip_indexing = true
    tn.taxon.skip_indexing = true
    taxon_ids_to_index << tn.taxon_id
    if tn.valid?
      tn.save unless @opts.dry
      updated << tn
    else
      puts "Failed to save #{tn}, errors: #{tn.errors.full_messages.to_sentence}" if @opts.debug
      tn.destroy unless @opts.dry
      deleted << tn
    end
  end
  puts
end

nillable_lexicons = TaxonName::FORBIDDEN_LEXICONS + ["''", "Other", "Lexicon", "Lexicon 1", "Unknown"]
und_scope = TaxonName.where( lexicon: nillable_lexicons )
puts
puts "== Removing lexicons for unknown =="
puts
puts "Removing lexicon from #{und_scope.count} names with these lexicons: #{nillable_lexicons}"
und_scope.update_all( "lexicon = null" )

puts
puts "== PROBLEM LEXICONS =="
puts
puts <<~TXT
  Just a place to put lexicons that seem less than great but it's not clear what
  to do about them.
TXT
problem_lexicons = [
  { lexicon: nil, comment: "We used to allow blank lexicons, now these names need to be manually fixed or removed" },
  { lexicon: "", comment: "Should get lumped with nil" },
  { lexicon: "Other", comment: "Should get lumped with nil" },
  { lexicon: "Chinese", comment: "Which version of Chinese does this mean?" },
  {
    lexicon: "Informal Latinized Name (Vernacular Concept Only)",
    comment: "Might be names added just so things have a common name. Most seem English-y, so... delete?"
  },
  {
    lexicon: "Latin",
    comment: "This is mostly used to mistakenly add scientific names, but there are a few legit Latin names"
  },
  {
    lexicon: "Manx English Dialect",
    comment: <<~TXT
      This might just be English that should have a PlaceTaxonName set to the
      Isle of Man, as opposed to Manx which seems like a variant of Gaelic
      endemic to the Isle of Man"
    TXT
  },
  {
    lexicon: "Scots",
    comment: "Seems like a mix of regional English names and Scots Gaelic names"
  },
  { lexicon: "Unknown", comment: "Should get lumped with nil" },
  { lexicon: "New Zealand", comment: "Not clear if these are English or Maori" },
  { lexicon: "Lexicon", comment: "Should get lumped with nil" },
  { lexicon: "Lexicon 1", comment: "Should get lumped with nil" },
  { lexicon: "Brazil", comment: "Probably Portuguese, but can we be sure?" },
  {
    lexicon: "Indigenous Australian",
    comment: "There are at least 250 indigenous Australian languages so this is ambiguous"
  },
  { lexicon: "Creole (English)", comment: "There are many English creoles" },
  { lexicon: "English (Creole)", comment: "There are many English creoles" }
]
problem_lexicons.each do | l |
  puts l[:lexicon].inspect
  puts "\t#{l[:comment]}"
  puts "\t#{TaxonName.where( lexicon: l[:lexicon] ).count} names"
end

taxon_ids_to_index.uniq!
puts
puts "== REINDEXING #{taxon_ids_to_index.size} TAXA =="
puts
Taxon.elastic_index!( ids: taxon_ids_to_index ) unless @opts.dry

puts
puts "== REPORT =="
puts
puts "#{updated.size} names updated"
puts "#{deleted.size} names deleted"
puts "#{created_ptns.size} place taxon names created"
puts "#{invalid_ptns.size} place taxon names not created"
puts "#{Time.now - start} s elapsed"
puts
