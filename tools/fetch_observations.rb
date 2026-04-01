#!/usr/bin/env ruby
# frozen_string_literal: true

# Fetches N random observations from an iNaturalist project and writes a JSON
# file containing, for each observation:
#   - user_name             : observer's login
#   - user_icon_url         : observer's avatar URL
#   - user_icon_file        : downloaded + WebP-converted avatar path
#   - scientific_name       : taxon scientific name
#   - common_names          : { locale => preferred common name } for every
#                             locale present in config/locales/
#   - taxon_thumbnail_url   : taxon default photo square URL
#   - taxon_thumbnail_file  : downloaded + WebP-converted taxon thumbnail path
#   - observation_photo_url : first observation photo URL (medium size)
#   - observation_photo_file: downloaded, resized to 300px wide, WebP path
#   - place_guess           : human-readable location string
#   - coordinates           : { lat, lng } or null
#
# Common names are resolved by making one v2 API request per locale (using the
# ?locale= parameter), so the total request count is 1 + number_of_locales.
#
# Prerequisites:
#   ImageMagick 7+  (brew install imagemagick)
#   Ruby stdlib only — no other gems required.
#
# Usage:
#   ruby tools/fetch_observations.rb --project ID [options]
#
# Examples:
#   ruby tools/fetch_observations.rb --project 29905 --count 5
#   ruby tools/fetch_observations.rb --project 29905 --count 20 \
#     --output out.json --output-dir ./images
#   ruby tools/fetch_observations.rb --project 29905 --dry-run

require "json"
require "net/http"
require "optparse"
require "fileutils"
require "set"
require "shellwords"
require "tempfile"
require "uri"

LOCALES_DIR   = File.expand_path("../config/locales", __dir__).freeze
BASE_URL      = "https://api.inaturalist.org/v2".freeze
MAX_PER_PAGE  = 200
RATE_LIMIT_S  = 1.0  # seconds between API requests
MAX_RETRIES   = 3    # retries on 429

# Fields for the initial observation fetch.
OBS_FIELDS = (
  "(id:!t," \
  "user:(login:!t,icon_url:!t)," \
  "taxon:(name:!t,preferred_common_name:!t,default_photo:(square_url:!t))," \
  "photos:(url:!t)," \
  "place_guess:!t," \
  "location:!t)"
).freeze

# Fields for the per-locale common-name pass.
NAME_FIELDS = "(id:!t,taxon:(preferred_common_name:!t))".freeze

# Fields for the sample observation (same as OBS_FIELDS plus observed_on).
SAMPLE_OBS_FIELDS = (
  "(id:!t," \
  "user:(login:!t,icon_url:!t)," \
  "taxon:(name:!t,preferred_common_name:!t,default_photo:(square_url:!t))," \
  "photos:(url:!t)," \
  "place_guess:!t," \
  "location:!t," \
  "observed_on:!t)"
).freeze

# Fields for story observations (taxon common names only).
STORY_OBS_FIELDS = "(id:!t,taxon:(preferred_common_name:!t))".freeze

# ── CLI options ───────────────────────────────────────────────────────────────

options = {
  project:     nil,
  count:       20,
  output:      nil,
  output_dir:  nil,
  locales_dir: LOCALES_DIR,
  base_url:    BASE_URL,
  rate_limit:  RATE_LIMIT_S,
  dry_run:     false,
  wipe:        false,
  sample_id:   nil,
  story_ids:   [],
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby tools/fetch_observations.rb --project ID [options]"

  opts.on("--project ID", "iNaturalist project ID or slug (required)") \
    { |v| options[:project] = v }

  opts.on("--count N", Integer,
    "Number of observations to fetch (default: #{options[:count]}, max: #{MAX_PER_PAGE})") \
    { |v| options[:count] = v }

  opts.on("--output FILE", "Write JSON to FILE (default: stdout)") \
    { |v| options[:output] = v }

  opts.on("--output-dir DIR",
    "Download images into DIR (skipped if omitted)") \
    { |v| options[:output_dir] = v }

  opts.on("--locales-dir DIR",
    "Path to config/locales directory (default: auto-detected from script location)") \
    { |v| options[:locales_dir] = v }

  opts.on("--base-url URL",
    "API base URL (default: #{BASE_URL})") \
    { |v| options[:base_url] = v }

  opts.on("--rate-limit SECONDS", Float,
    "Seconds to wait between locale requests (default: #{RATE_LIMIT_S})") \
    { |v| options[:rate_limit] = v }

  opts.on("--dry-run", "Show configuration and locale list without fetching") \
    { options[:dry_run] = true }

  opts.on("--wipe", "Delete all files in --output-dir before downloading") \
    { options[:wipe] = true }

  opts.on("--sample-id ID", Integer,
    "Observation ID for the sample observation section") \
    { |v| options[:sample_id] = v }

  opts.on("--story-ids IDs",
    "Comma-separated observation IDs for story card backgrounds (in display order)") \
    { |v| options[:story_ids] = v.split( "," ).map( &:to_i ) }
end.parse!

abort "Error: --project is required. Run with --help for usage." unless options[:project]

# ── Locale loading ────────────────────────────────────────────────────────────

def load_locales(dir)
  abort "Error: locales directory not found: #{dir}" unless Dir.exist?(dir)

  Dir.children(dir)
    .select { |f| f.end_with?(".yml") }
    .map    { |f| f.delete_suffix(".yml") }
    .reject { |code| code == "qqq" || code.start_with?("doorkeeper.") }
    .sort
end

locales = load_locales(options[:locales_dir])
warn "Loaded #{locales.size} locale codes from #{options[:locales_dir]}"

if options[:dry_run]
  warn "Locales: #{locales.join(", ")}"
  warn ""
  warn "Would fetch #{options[:count]} observations from project #{options[:project]}"
  warn "  API:        #{options[:base_url]}"
  warn "  Requests:   1 (observations) + #{locales.size} (locale names) = #{1 + locales.size}"
  warn "  Output:     #{options[:output] || "(stdout)"}"
  warn "  Images:     #{options[:output_dir] || "(not downloaded)"}"
  exit 0
end

# ── HTTP helpers ──────────────────────────────────────────────────────────────

USER_AGENT = "inat-fetch-observations/1.0".freeze

def http_get(url, max_redirects: 5)
  uri = URI(url)
  max_redirects.times do
    response = nil
    MAX_RETRIES.times do |attempt|
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.get(uri.request_uri, "User-Agent" => USER_AGENT, "Accept" => "application/json")
      end
      break unless response.code == "429"
      wait = (response["Retry-After"] || (2 ** attempt * 5)).to_i
      warn "  Rate limited — waiting #{wait}s before retry..."
      sleep wait
    end
    case response
    when Net::HTTPSuccess     then return response.body
    when Net::HTTPRedirection then uri = URI(response["Location"])
    else abort "Error: HTTP #{response.code} fetching #{url}"
    end
  end
  abort "Error: too many redirects for #{url}"
end

def download_raw(url, path, max_redirects: 5)
  return nil unless url

  uri = URI(url)
  max_redirects.times do
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.get(uri.request_uri, "User-Agent" => USER_AGENT)
    end
    case response
    when Net::HTTPSuccess
      File.binwrite(path, response.body)
      return path
    when Net::HTTPRedirection
      uri = URI(response["Location"])
    else
      warn "  Warning: HTTP #{response.code} downloading #{url}"
      return nil
    end
  end
  warn "  Warning: too many redirects for #{url}"
  nil
end

# Download url, convert to WebP (optionally resizing to resize_width px wide),
# save to out_path. Returns out_path on success, nil on failure.
def download_as_webp(url, out_path, resize_width: nil)
  return nil unless url

  # Download to a temp file so ImageMagick can read any source format.
  ext = File.extname(URI(url).path).then { |e| e.empty? ? ".jpg" : e }
  tmp = Tempfile.new(["inat_img", ext], binmode: true)
  begin
    return nil unless download_raw(url, tmp.path)

    resize_arg = resize_width ? "-resize #{resize_width}x" : ""
    cmd = "magick #{tmp.path.shellescape} #{resize_arg} webp:#{out_path.shellescape}"
    unless system(cmd, out: File::NULL, err: File::NULL)
      warn "  Warning: magick conversion failed for #{url}"
      return nil
    end
    out_path
  ensure
    tmp.close
    tmp.unlink
  end
end

# Replace the size segment in an iNaturalist photo URL.
# e.g. ".../square.jpg" → ".../medium.jpg"
def inat_photo_url(url, size)
  return nil unless url
  url.sub(%r{/(square|thumb|small|medium|large|original)(\.(?:jpe?g|png|gif|webp))}, "/#{size}\\2")
end

# ── Data extraction ───────────────────────────────────────────────────────────

def parse_location(location)
  return nil unless location

  parts = location.split(",")
  return nil unless parts.size == 2

  { "lat" => parts[0].to_f, "lng" => parts[1].to_f }
end


def build_record(obs)
  user  = obs["user"]  || {}
  taxon = obs["taxon"] || {}
  # Use medium size (~500px) as source for the observation photo so there's
  # enough resolution to resize down to 300px wide.
  photo_url = inat_photo_url((obs["photos"] || []).dig(0, "url"), "medium")

  {
    "id"                    => obs["id"],
    "user_name"             => user["login"],
    "user_icon_url"         => user["icon_url"],
    "scientific_name"       => taxon["name"],
    "common_names"          => {},
    "taxon_thumbnail_url"   => taxon.dig("default_photo", "square_url"),
    "observation_photo_url" => photo_url,
    "place_guess"           => obs["place_guess"],
    "coordinates"           => parse_location(obs["location"]),
  }
end

def build_sample_record(obs)
  build_record(obs).merge("observed_on" => obs["observed_on"])
end

# ── Fetch observations ────────────────────────────────────────────────────────

target     = options[:count]
batch_size = [target, MAX_PER_PAGE].min
seen_ids   = Set.new
named_obs  = []
page       = 1

warn "Fetching observations from project #{options[:project]} (target: #{target})..."

until named_obs.size >= target
  sleep options[:rate_limit] if page > 1

  params = URI.encode_www_form(
    project_id: options[:project],
    per_page:   batch_size,
    page:       page,
    order_by:   "created_at",
    order:      "desc",
    locale:     "en",
    fields:     OBS_FIELDS,
  )
  body    = http_get("#{options[:base_url]}/observations?#{params}")
  results = JSON.parse(body)["results"] || []

  if results.empty?
    warn "Warning: project pool exhausted on page #{page} — only #{named_obs.size} of #{target} observations found."
    break
  end

  # Deduplicate in case of any overlap between pages.
  fresh  = results.reject { |obs| seen_ids.include?(obs["id"]) }
  seen_ids.merge(results.map { |obs| obs["id"] })

  needed = target - named_obs.size
  named_obs.concat(fresh.first(needed))

  warn "  Page #{page}: #{fresh.size} observations" \
       "#{named_obs.size < target ? ", #{target - named_obs.size} still needed" : ""}"

  page += 1
end

warn "Retrieved #{named_obs.size} observations."

records = named_obs.map { |obs| build_record(obs) }

# ── Fetch sample observation ──────────────────────────────────────────────────

sample_record = nil
if options[:sample_id]
  warn "Fetching sample observation #{options[:sample_id]}..."
  params = URI.encode_www_form( id: options[:sample_id], fields: SAMPLE_OBS_FIELDS, locale: "en" )
  body   = http_get( "#{options[:base_url]}/observations?#{params}" )
  obs    = JSON.parse( body )["results"]&.first
  if obs
    sample_record = build_sample_record( obs )
    warn "  Got: #{sample_record["scientific_name"]} by #{sample_record["user_name"]}"
  else
    warn "  Warning: observation #{options[:sample_id]} not found."
  end
end

# ── Fetch story observations ──────────────────────────────────────────────────

story_records = []
if options[:story_ids].any?
  warn "Fetching #{options[:story_ids].size} story observation(s)..."
  params  = URI.encode_www_form( id: options[:story_ids].join( "," ), fields: STORY_OBS_FIELDS )
  body    = http_get( "#{options[:base_url]}/observations?#{params}" )
  by_id   = ( JSON.parse( body )["results"] || [] ).each_with_object( {} ) { |obs, h| h[obs["id"]] = obs }
  # Preserve the caller-specified display order.
  story_records = options[:story_ids].map do |id|
    next unless ( obs = by_id[id] )

    en_name = obs.dig( "taxon", "preferred_common_name" )
    { "id" => id, "en_name" => en_name, "common_names" => { "en" => en_name } }
  end.compact
  warn "  Got #{story_records.size} of #{options[:story_ids].size} story observation(s)."
end

# ── Fetch common names per locale ─────────────────────────────────────────────

# Include the sample observation in the locale pass so it gets common names too.
locale_records = records + [sample_record].compact + story_records
records_by_id  = locale_records.each_with_object( {} ) { |r, h| h[r["id"]] = r }
obs_ids        = locale_records.map { |r| r["id"] }.compact

if obs_ids.any?
  warn "Fetching common names for #{locales.size} locales..."
  ids_param = obs_ids.join(",")

  locales.each_with_index do |locale, i|
    sleep options[:rate_limit] if i > 0
    warn "  [#{i + 1}/#{locales.size}] #{locale}"
    params = URI.encode_www_form(
      id:     ids_param,
      locale: locale,
      fields: NAME_FIELDS,
    )
    body = http_get("#{options[:base_url]}/observations?#{params}")
    JSON.parse(body).fetch("results", []).each do |obs|
      name = obs.dig("taxon", "preferred_common_name")
      next unless name && (rec = records_by_id[obs["id"]])

      rec["common_names"][locale] = name
    end
  end
end

# ── Download images ───────────────────────────────────────────────────────────

if options[:output_dir]
  if options[:wipe] && Dir.exist?(options[:output_dir])
    Dir.glob(File.join(options[:output_dir], "*.webp")).each { |f| File.delete(f) }
    warn "Wiped *.webp from #{options[:output_dir]}"
  end
  FileUtils.mkdir_p(options[:output_dir])
  warn "Downloading images to #{options[:output_dir]}..."

  records.each do |rec|
    id = rec["id"]
    next unless id

    [
      ["user_icon_url",         "user_icon_file",          "#{id}_user.webp",        nil],
      ["taxon_thumbnail_url",   "taxon_thumbnail_file",    "#{id}_taxon.webp",       nil],
      ["observation_photo_url", "observation_photo_file",  "#{id}_observation.webp", 300],
    ].each do |url_key, file_key, filename, resize_width|
      img_url = rec[url_key]
      next unless img_url

      path = File.join(options[:output_dir], filename)
      warn "  #{filename}"
      rec[file_key] = download_as_webp(img_url, path, resize_width: resize_width)
    end
  end

  # Sample observation images (larger photo for prominence).
  if sample_record
    id = sample_record["id"]
    [
      ["user_icon_url",         "user_icon_file",          "sample_#{id}_user.webp",        nil],
      ["taxon_thumbnail_url",   "taxon_thumbnail_file",    "sample_#{id}_taxon.webp",        nil],
      ["observation_photo_url", "observation_photo_file",  "sample_#{id}_observation.webp",  600],
    ].each do |url_key, file_key, filename, resize_width|
      img_url = sample_record[url_key]
      next unless img_url

      path = File.join(options[:output_dir], filename)
      warn "  #{filename}"
      sample_record[file_key] = download_as_webp(img_url, path, resize_width: resize_width)
    end
  end

end

# ── Output ────────────────────────────────────────────────────────────────────

# Build stories as a hash keyed by English common name for easy locale lookup.
stories_output = story_records.each_with_object( {} ) do |rec, h|
  h[rec["en_name"]] = rec["common_names"]
end

output = {
  "explore" => records,
  "sample"  => sample_record,
  "stories" => stories_output,
}

json_output = JSON.pretty_generate(output)

if options[:output]
  File.write(options[:output], json_output, encoding: "utf-8")
  warn "Wrote #{records.size} explore + sample + #{story_records.size} story record(s) to #{options[:output]}"
else
  puts json_output
end
