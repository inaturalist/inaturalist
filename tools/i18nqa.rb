#encoding: utf-8
require "rubygems"
require "optimist"

OPTS = Optimist::options do
    banner <<-EOS

Check translations for missing variables and the like.

Usage:

  rails runner tools/i18nqa.rb

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :locale, "Only check this locale", type: :string, short: "-l"
  opt :search, "Filter keys by this substring", type: :string, short: "-s"
  opt :something, "something", type: :string
  opt :level,
    "Show only this error level. Set to all to show warnings and errors",
    type: :string, default: "error"
end

@levels = %w(error warning)
if OPTS.level
  if @levels.include?( OPTS.level )
    @levels = [OPTS.level]
  elsif OPTS.level != "all"
    Optimist::die :level, "must be `error`, `warning`, or `all`"
  end
end

def traverse( obj, key = nil, &blk )
  case obj
  when Hash
    # Kind of a lame hack to detect situations when translatewiki has translated
    # an array as a hash with numbered keys. They generally don't translate
    # position 0, so if the first key is a number greater than zero, we assume
    # it's one of those arrays here.
    if obj.keys.first.to_s.to_i > 0
      blk.call( obj, key )
    else
      obj.each {|k,v| traverse( v, [key, k].compact.join( "." ), &blk ) }
    end
  # Note that dealing with arrays here is generally unecessary. If it's really
  # an array, we just call the blk on it like we do with any other object
  # when Array
  #   obj.each_with_index {|v,i| traverse( v, "#{[key, i].compact.join( "." )}", &blk ) }
  else
    blk.call( obj, key )
  end
end

data = {}
key_counts = {}

Dir.glob( "config/locales/*.yml" ).each do |path|
  next if path =~ /qqq.yml/
  next if OPTS.locale && path !~ /#{OPTS.locale}.yml/ && path !~ /en.yml/
  traverse( YAML.load_file( path ) ) do |translation, key|
    # puts "translation: #{translation}, key: #{key}"
    data[key] = translation
    key_counts[key.split( "." )[1]] = key_counts[key.split( "." )[1]].to_i + 1
  end
end

problems = {}

if OPTS.debug
  puts
  puts "Found #{data.size} translations of #{key_counts.size} keys"
  puts
end

data.each do |key, translation|
  next if key =~ /^en\./
  next if OPTS.search && key !~ /#{OPTS.search}/
  puts "#{key}: #{translation}" if OPTS.debug
  locale = key[/^(.+?)\./, 1]
  en_key = key.sub( "#{locale}.", "en." )
  # puts "\tdata[#{en_key}]: #{data[en_key]}"
  if translation.is_a?( String ) && @levels.include?( "error" )
    translation.scan( /\{\{.+?\=.+?\}\}/ ).each do |match|
      problems[key] = problems[key] || []
      problems[key] << "**ERROR:** Invalid code formatting: `#{match}`"
    end
    translation.scan( /\{\{PLURAL.+?\}\}/ ).each do |match|
      problems[key] = problems[key] || []
      problems[key] << "**ERROR:** Invalid pluralization formatting: `#{match}`"
    end
  end
  if key =~ /^#{locale}\.i18n\.inflections\.gender\.$/
    problems[key] = problems[key] || []
      problems[key] << "**ERROR:** Gender inflection with a blank key"
  end
  next unless data[en_key]
  if data[en_key].is_a?( Array )
    # For some reason, translatewiki tends to translate yaml arrays as yaml
    # hashes with numbered keys. Our arrays often begin with a blank for
    # position 0, and translatewiki tends not to include that in their hash, so
    # ignore that in the count
    en_array_size = data[en_key].size
    en_array_size -= 1 if data[en_key][0].blank?
    if en_array_size > translation.size && @levels.include?( "error" )
      problems[key] = problems[key] || []
      problems[key] << "**ERROR:** Missing #{en_array_size - translation.size} items"
    end
    next
  elsif !data[en_key].is_a?( String )
    next
  end
  if translation.blank? && @levels.include?( "warning" )
    problems[key] = problems[key] || []
    problems[key] << "WARNING: Translation is blank"
    next
  end
  variables = data[en_key].scan( /%{.+?}/ )
  variables.each do |variable|
    # puts "\tVariable: #{variable}"
    if translation !~ /#{variable}/ && @levels.include?( "warning" )
      problems[key] = problems[key] || []
      problems[key] << "WARNING: Should include `#{variable}`"
    end
  end
  extraneous_variables = translation.scan( /%{.+?}/ )
  extraneous_variables.each do |extraneous_variable|
    if data[en_key] !~ /#{extraneous_variable.encode( "utf-8" )}/ && @levels.include?( "error" )
      problems[key] = problems[key] || []
      problems[key] << "**ERROR:** Must not include `#{extraneous_variable}`"
    end
  end

  # These should not be necessary now that we're using the rails-i18n gem
  # if key =~ /#{locale}\..+\.one$/
  #   other_key = key.sub( /\.one$/ , ".other" )
  #   if !data[other_key] && @levels.include?( "error" )
  #     problems[other_key] = problems[other_key] || []
  #     problems[other_key] << "**ERROR:** Missing part of a plural key"
  #   end
  # end
  # if key =~ /#{locale}\..+\.other$/
  #   one_key = key.sub( /\.other$/ , ".one" )
  #   if !data[one_key] && @levels.include?( "error" )
  #     problems[one_key] = problems[one_key] || []
  #     problems[one_key] << "**ERROR:** Missing part of a plural key"
  #   end
  # end

  # https://stackoverflow.com/a/3314572
  if @levels.include?( "error" ) && translation =~ /<\/?\s+[^\s]+>/
    problems[key] = problems[key] || []
    problems[key] << "**ERROR:** HTML tag with leading space"
  end
end

problems.each do |key, a|
  data[key] = data[key].strip if data[key].is_a?( String )
  if data[key] =~ /\n/
    puts "* `#{key}`:"
    puts "  ```html"
    puts "  #{data[key].split( "\n" ).join( "\n  " )}"
    puts "  ```"
  else
    puts "* `#{key}`: `#{data[key]}`"
  end
  a.each do |problem|
    puts "  - [ ] #{problem}"
  end
end
