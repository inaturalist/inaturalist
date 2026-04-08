#!/usr/bin/env ruby
# Detects which non-Latin scripts are used in locale translations, downloads
# the corresponding Noto Serif font files from GitHub, subsets them to only
# the required characters, and outputs .woff2 files.
#
# Font sources:
#   CJK (JP/KR/SC/TC) — OTF ZIPs from github.com/notofonts/noto-cjk releases
#   All others        — TTF files from github.com/notofonts/noto-fonts monorepo
#   Arabic            — NotoNaskhArabic (NotoSerifArabic not yet published)
#
# Prerequisites:
#   pip install fonttools brotli   # brotli required for woff2 output
#   curl + unzip                   # standard on macOS/Linux
#
# Usage:
#   ruby tools/subset_noto.rb [options]
#
# Examples:
#   ruby tools/subset_noto.rb --dry-run
#   ruby tools/subset_noto.rb --weights 400,700 --keys views.welcome_v2
#   ruby tools/subset_noto.rb --weights 400,700 --keys views.welcome_v2,views.shared
#   ruby tools/subset_noto.rb --keys views.welcome_v2 --keys views.shared
#   ruby tools/subset_noto.rb --weights 400,700 --output-dir public/fonts/noto

require "yaml"
require "set"
require "optparse"
require "fileutils"
require "tmpdir"
require "shellwords"
require "uri"
require "json"
require "open-uri"

LOCALES_DIR    = File.expand_path("../config/locales", __dir__)
DEFAULT_OUTPUT = File.expand_path("../public/fonts/noto", __dir__)

NOTO_MONOREPO_BASE = "https://raw.githubusercontent.com/notofonts/noto-fonts/main/hinted/ttf"
NOTO_CJK_API       = "https://api.github.com/repos/notofonts/noto-cjk/releases/latest"
PYFTSUBSET = begin
  candidates = [
    `which pyftsubset 2>/dev/null`.strip,
    File.expand_path("~/.pyenv/shims/pyftsubset"),
    "/usr/local/bin/pyftsubset",
    "/opt/homebrew/bin/pyftsubset",
  ]
  candidates.find { |p| p && !p.empty? && File.executable?(p) } \
    or abort("pyftsubset not found. Run: pip install fonttools brotli")
end

LATIN_RANGES = [
  0x0020..0x007E,   # Basic Latin
  0x00A0..0x00FF,   # Latin-1 Supplement
  0x0100..0x017F,   # Latin Extended-A
  0x0180..0x024F,   # Latin Extended-B
  0x2000..0x206F,   # General Punctuation
].freeze

WEIGHT_NAMES = {
  100 => "Thin",
  200 => "ExtraLight",
  300 => "Light",
  400 => "Regular",
  500 => "Medium",
  600 => "SemiBold",
  700 => "Bold",
  800 => "ExtraBold",
  900 => "Black",
}.freeze

# ── Script definitions ────────────────────────────────────────────────────────
# source: :cjk      — downloaded from noto-cjk GitHub release ZIPs
#   zip_name        — asset filename in the release (e.g. "12_NotoSerifJP.zip")
#   cjk_lang        — subdirectory inside ZIP (e.g. "JP")
#   family_slug     — font filename prefix inside ZIP (e.g. "NotoSerifJP")
#
# source: :monorepo — individual TTF from noto-fonts monorepo raw content
#   family_slug     — directory + filename prefix (e.g. "NotoSerifDevanagari")
#
# font_family       — CSS font-family name declared in @font-face
# locales           — locale codes whose translations we scan for this script
# ranges            — unicode ranges that define this script's characters
SCRIPTS = {
  "JP" => {
    source:      :cjk,
    zip_name:    "12_NotoSerifJP.zip",
    cjk_lang:    "JP",
    family_slug: "NotoSerifJP",
    font_family: "Noto Serif JP",
    locales:     %w[ja ja-phonetic],
    ranges:      LATIN_RANGES + [0x3000..0x303F, 0x3040..0x309F, 0x30A0..0x30FF,
                               0x31F0..0x31FF, 0x4E00..0x9FFF, 0xF900..0xFAFF,
                               0xFF00..0xFFEF],
  },
  "KR" => {
    source:      :cjk,
    zip_name:    "13_NotoSerifKR.zip",
    cjk_lang:    "KR",
    family_slug: "NotoSerifKR",
    font_family: "Noto Serif KR",
    locales:     %w[ko],
    ranges:      LATIN_RANGES + [0x1100..0x11FF, 0x3130..0x318F, 0xA960..0xA97F,
                               0xAC00..0xD7AF, 0xD7B0..0xD7FF],
  },
  "SC" => {
    source:      :cjk,
    zip_name:    "14_NotoSerifSC.zip",
    cjk_lang:    "SC",
    family_slug: "NotoSerifSC",
    font_family: "Noto Serif SC",
    locales:     %w[zh-CN],
    ranges:      LATIN_RANGES + [0x3400..0x4DBF, 0x4E00..0x9FFF, 0xF900..0xFAFF],
  },
  "TC" => {
    source:      :cjk,
    zip_name:    "15_NotoSerifTC.zip",
    cjk_lang:    "TC",
    family_slug: "NotoSerifTC",
    font_family: "Noto Serif TC",
    locales:     %w[zh-TW zh-HK],
    ranges:      LATIN_RANGES + [0x3400..0x4DBF, 0x4E00..0x9FFF, 0xF900..0xFAFF],
  },
  "Arabic" => {
    source:      :monorepo,
    family_slug: "NotoNaskhArabic",       # NotoSerifArabic not yet published
    font_family: "Noto Serif Arabic",
    locales:     %w[ar fa],
    ranges:      [0x0600..0x06FF, 0x0750..0x077F, 0x08A0..0x08FF,
                  0xFB50..0xFDFF, 0xFE70..0xFEFF],
  },
  "Thai" => {
    source:      :monorepo,
    family_slug: "NotoSerifThai",
    font_family: "Noto Serif Thai",
    locales:     %w[th],
    ranges:      [0x0E00..0x0E7F],
  },
  "Devanagari" => {
    source:      :monorepo,
    family_slug: "NotoSerifDevanagari",
    font_family: "Noto Serif Devanagari",
    locales:     %w[hi mr],
    ranges:      [0x0900..0x097F, 0xA8E0..0xA8FF],
  },
  "Gujarati" => {
    source:      :monorepo,
    family_slug: "NotoSerifGujarati",
    font_family: "Noto Serif Gujarati",
    locales:     %w[gu],
    ranges:      [0x0A80..0x0AFF],
  },
  "Tamil" => {
    source:      :monorepo,
    family_slug: "NotoSerifTamil",
    font_family: "Noto Serif Tamil",
    locales:     %w[ta],
    ranges:      [0x0B80..0x0BFF],
  },
  "Telugu" => {
    source:      :monorepo,
    family_slug: "NotoSerifTelugu",
    font_family: "Noto Serif Telugu",
    locales:     %w[te],
    ranges:      [0x0C00..0x0C7F],
  },
  "Kannada" => {
    source:      :monorepo,
    family_slug: "NotoSerifKannada",
    font_family: "Noto Serif Kannada",
    locales:     %w[kn],
    ranges:      [0x0C80..0x0CFF],
  },
  "Malayalam" => {
    source:      :monorepo,
    family_slug: "NotoSerifMalayalam",
    font_family: "Noto Serif Malayalam",
    locales:     %w[ml],
    ranges:      [0x0D00..0x0D7F],
  },
  "Bengali" => {
    source:      :monorepo,
    family_slug: "NotoSerifBengali",
    font_family: "Noto Serif Bengali",
    locales:     %w[bn sat],
    ranges:      [0x0980..0x09FF],
  },
  "Sinhala" => {
    source:      :monorepo,
    family_slug: "NotoSerifSinhala",
    font_family: "Noto Serif Sinhala",
    locales:     %w[si],
    ranges:      [0x0D80..0x0DFF],
  },
  "Georgian" => {
    source:      :monorepo,
    family_slug: "NotoSerifGeorgian",
    font_family: "Noto Serif Georgian",
    locales:     %w[ka],
    ranges:      [0x10A0..0x10FF, 0x2D00..0x2D2F, 0x1C90..0x1CBF],
  },
}.freeze

# ── CLI options ───────────────────────────────────────────────────────────────

options = {
  keys:       ["*"],
  weights:    [400, 700],
  output_dir: DEFAULT_OUTPUT,
  dry_run:    false,
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby tools/subset_noto.rb [options]"

  opts.on("--keys PATH[,PATH...]",
    "Comma-separated YAML key paths to scan (default: *). Use '*' for entire file.",
    "May be specified multiple times to accumulate paths.",
    "Example: --keys views.welcome_v2,views.shared") \
    do |k|
      new_keys = k.split(",").map(&:strip)
      options[:keys] = (options[:keys] == ["*"] ? [] : options[:keys]) + new_keys
    end

  opts.on("--weights LIST",
    "Comma-separated font weights to download and subset (default: 400,700)") \
    { |w| options[:weights] = w.split(",").map(&:strip).map(&:to_i) }

  opts.on("--output-dir DIR",
    "Output directory for .woff2 files (default: #{DEFAULT_OUTPUT})") \
    { |d| options[:output_dir] = d }

  opts.on("--dry-run", "Print actions without downloading or running pyftsubset") \
    { options[:dry_run] = true }
end.parse!

# ── Helpers ───────────────────────────────────────────────────────────────────

def dig_keys(hash, key_path)
  return hash if key_path == "*"
  key_path.split(".").reduce(hash) { |h, k| h.is_a?(Hash) ? h[k] : nil }
end

def flatten_strings(obj)
  case obj
  when String then [obj]
  when Hash   then obj.values.flat_map { |v| flatten_strings(v) }
  when Array  then obj.flat_map { |v| flatten_strings(v) }
  else []
  end
end

def extract_chars(locale_code, key_paths)
  path = File.join(LOCALES_DIR, "#{locale_code}.yml")
  return Set.new unless File.exist?(path)

  data = YAML.load_file(path, permitted_classes: [Symbol], symbolize_names: false)
  root = data.values.first

  Array(key_paths).each_with_object(Set.new) do |key_path, set|
    subtree = dig_keys(root, key_path)
    next unless subtree
    flatten_strings(subtree).each { |s| s.each_char { |c| set << c } }
  end
rescue => e
  warn "  Warning: could not parse #{locale_code}.yml: #{e.message}"
  Set.new
end

def in_ranges?(codepoint, ranges)
  ranges.any? { |r| r.include?(codepoint) }
end

def curl!(url, dest)
  system("curl -fsSL -o #{dest.shellescape} #{url.shellescape}") \
    or abort("curl failed: #{url}")
end

# Downloads individual TTF files from the noto-fonts monorepo.
def download_monorepo(family_slug, weights, dest_dir, dry_run:)
  weights.filter_map do |w|
    weight_name = WEIGHT_NAMES[w] or abort("Unknown weight: #{w}")
    filename    = "#{family_slug}-#{weight_name}.ttf"
    url         = "#{NOTO_MONOREPO_BASE}/#{family_slug}/#{filename}"
    dest        = File.join(dest_dir, filename)

    if dry_run
      puts "  [download] #{url}"
      dest
    else
      puts "  Downloading #{filename}..."
      curl!(url, dest)
      dest
    end
  end
end

# Downloads a CJK font ZIP from the noto-cjk GitHub release and extracts OTFs.
# Fetches the latest release tag dynamically from the GitHub API.
def download_cjk(zip_name, cjk_lang, family_slug, weights, dest_dir, dry_run:)
  # Lazy-fetch and cache the latest noto-cjk release tag
  unless defined?(@cjk_release_tag)
    if dry_run
      @cjk_release_tag = "<latest-serif-tag>"
    else
      puts "  Fetching latest noto-cjk release tag..."
      data = JSON.parse(URI.open(NOTO_CJK_API, "User-Agent" => "subset_noto.rb").read)
      @cjk_release_tag = data["tag_name"]
      puts "  noto-cjk tag: #{@cjk_release_tag}"
    end
  end

  zip_url    = "https://github.com/notofonts/noto-cjk/releases/download/#{@cjk_release_tag}/#{zip_name}"
  zip_path   = File.join(dest_dir, zip_name)
  otf_files  = weights.map do |w|
    weight_name = WEIGHT_NAMES[w] or abort("Unknown weight: #{w}")
    "SubsetOTF/#{cjk_lang}/#{family_slug}-#{weight_name}.otf"
  end

  if dry_run
    puts "  [download] #{zip_url}"
    otf_files.each { |f| puts "  [extract]  #{f}" }
    return otf_files.map { |f| File.join(dest_dir, File.basename(f)) }
  end

  puts "  Downloading #{zip_name}..."
  curl!(zip_url, zip_path)

  puts "  Extracting #{otf_files.map { |f| File.basename(f) }.join(', ')}..."
  system("unzip -o -j #{zip_path.shellescape} #{otf_files.map(&:shellescape).join(' ')} -d #{dest_dir.shellescape}") \
    or abort("unzip failed for #{zip_name} — check that weight names exist inside the archive")

  File.delete(zip_path)

  otf_files.map { |f| File.join(dest_dir, File.basename(f)) }.select do |f|
    exists = File.exist?(f)
    warn "  Skipping #{File.basename(f)}: not found after extraction" unless exists
    exists
  end
end

# ── Main ──────────────────────────────────────────────────────────────────────

key_desc = options[:keys] == ["*"] ? "entire locale files" : options[:keys].map { |k| %("#{k}") }.join(", ")
puts "Scanning locale files (#{key_desc}) for non-Latin characters...\n\n"

needed = SCRIPTS.filter_map do |script, config|
  chars = config[:locales].each_with_object(Set.new) do |locale, set|
    extracted = extract_chars(locale, options[:keys])
    set.merge(extracted.select { |c| in_ranges?(c.ord, config[:ranges]) })
  end

  next if chars.empty?
  puts "  #{config[:font_family]}: #{chars.size} unique codepoints (locales: #{config[:locales].join(', ')})"
  puts "    #{chars.sort.join(' ')}" if options[:dry_run]
  { script: script, config: config, chars: chars }
end

if needed.empty?
  puts "No non-Latin characters found. Add translations for non-Latin locales and re-run."
  exit 0
end

puts "\nWeights to subset: #{options[:weights].join(', ')}"
puts "Output directory:  #{options[:output_dir]}\n\n"

FileUtils.mkdir_p(options[:output_dir]) unless options[:dry_run]

Dir.mktmpdir("noto_download") do |tmp|
  needed.each do |entry|
    script = entry[:script]
    config = entry[:config]
    chars  = entry[:chars]

    unicode_file = File.join(tmp, "#{script.downcase}.txt")
    File.write(unicode_file, chars.map(&:ord).sort.map { |cp| "U+%04X" % cp }.join(","))

    font_files = case config[:source]
    when :cjk
      download_cjk(config[:zip_name], config[:cjk_lang], config[:family_slug],
                   options[:weights], tmp, dry_run: options[:dry_run])
    when :monorepo
      download_monorepo(config[:family_slug], options[:weights], tmp,
                        dry_run: options[:dry_run])
    end

    font_files.each do |font_file|
      weight = options[:weights].find { |w| font_file.include?("-#{WEIGHT_NAMES[w]}.") } || 400
      output = File.join(options[:output_dir], "noto-serif-#{script.downcase}-#{weight}.woff2")

      cmd = [
        PYFTSUBSET, font_file,
        "--unicodes-file=#{unicode_file}",
        "--layout-features=*",
        "--flavor=woff2",
        "--output-file=#{output}"
      ].join(" ")

      if options[:dry_run]
        puts "  [subset]   #{File.basename(font_file)} → #{File.basename(output)}"
      else
        unless File.exist?(font_file)
          warn "  Skipping #{File.basename(font_file)}: file not found"
          next
        end
        puts "  Subsetting #{File.basename(font_file)} → #{File.basename(output)}"
        system(cmd) or warn "  pyftsubset failed for #{font_file}"
      end
    end

    puts unless options[:dry_run]
  end
end

puts "\nDone."
