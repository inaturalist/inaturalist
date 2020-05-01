require "rubygems"
require "optimist"

@opts = Optimist::options do
    banner <<-EOS
Generate attributions from a CSV export of the translators report on Crowdin.

Usage:

  rails runner tools/crowdin_top_members_to_markdown.rb /path/to/top_members.csv

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :indent, "Header indentation", type: :integer, short: "-i", default: 2
  opt :rails_only, "Filter out locales that aren't in the Rails repo", type: :boolean
end

if ARGV[0].blank?
  Optimist::die <<-TXT
    You must specify a Crowdin top members report CSV export from
    https://crowdin.com/project/inaturalistweb/settings#reports-top-members
  TXT
end

locale_codes_by_name = I18n.t(:locales).inject({}) do |memo, pair|
  memo[pair[1].parameterize] = pair[0]
  memo
end

headers = [
  "Name",
  "Languages",
  "Translated (Words)",
  "Target Words",
  "Approved (Words)",
  "Votes"
]
ci_authors = {}
CSV.foreach( ARGV[0], headers: headers ) do |line|
  next unless line["Languages"] && line["Languages"] != "Languages"
  line["Languages"].split(";").each do |language|
    language.strip!
    next if language == "English"
    ci_authors[language] ||= []
    ci_authors[language] << line["Name"]
  end
end

ci_authors.keys.sort.each do |language|
  locale = locale_codes_by_name[language.parameterize]
  authors = ci_authors[language].select{|author| author !~ /kueda|alexinat|loarie|carrieseltzer|kroodsmad|REMOVED_USER/}
  next if authors.blank?
  # # Uncomment if you want to only use locales in the rails repo
  if @opts.rails_only
    next unless File.exists?( File.join( Rails.root, "config", "locales", "#{locale}.yml" ) )
  end
  puts
  title = "#{'#' * @opts.indent} #{language}"
  title += " (`#{locale}`)" if locale
  puts title
  # authors are sorted by number of contributions desc by default
  authors.each do |author|
    username = author[/ \((.+)\)$/, 1] || author
    puts "* [#{author}](#{URI.encode( "https://crowdin.com/profile/#{username}" )})"
  end
end
