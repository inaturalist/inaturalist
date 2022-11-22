require "rubygems"
require "optimist"

OPTS = Optimist::options do
    banner <<-EOS
Export user data, mostly for use in fundraising campaigns.

BE CAREFUL. This exports a lot of personal information and the results are NOT
for general dissemination. Only share with staff except under special
circumstances.

Usage:

  rails runner tools/export_user_data.rb

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :file, "Where to write the data", :type => :string, :short => "-f"
  opt :min_active_date, "Minimum date of last user activity, YYYY-MM-DD format", type: :string, short: "-a"
  opt :exclude, "Path to file containing email addresses to exclude", type: :string, short: "-x"
  opt :place_ids, "Comma-separated list of place IDs to include obs counts for. Obs counts will be of all obs, not verifiable.", type: :string, short: "-p"
  opt :staff_only, "Only export data for staff for testing", type: :boolean
  opt :extras, "Path to a CSV file with headers to append to this file. Must have headers and an email column", type: :string
end

start = Time.now
user_count = 0
@work_path = Dir.mktmpdir
FileUtils.mkdir_p @work_path, :mode => 0755
@basename = "export-user-data-#{Date.today.to_s.gsub(/\-/, '')}-#{Time.now.to_i}"
@out_path = OPTS.file || File.join( @work_path, "#{@basename}.csv" )

scope = User.
  where( "NOT spammer AND suspended_at IS NULL AND email IS NOT NULL AND email != ''" ).
  includes( :site )

if OPTS.staff_only
  scope = scope.
    joins( "JOIN roles_users ON roles_users.user_id = users.id" ).
    where( "roles_users.role_id = ?", Role::ADMIN_ROLE.id )
end

if OPTS.min_active_date
  unless @min_active_date = Date.parse( OPTS.min_active_date )
    Optimist::die "Couldn't parse min_active_date from '#{OPTS.min_active_date}'"
  end
  scope = scope.where( "last_active >= ?", @min_active_date )
end

@emails_to_exclude = []
if OPTS.exclude
  unless File.exists?( OPTS.exclude )
    Optimist::die "Couldn't find file of emails to exclude at '#{OPTS.exclude}'"
  end
  @emails_to_exclude = File.readlines( OPTS.exclude ).map(&:chomp).sort
end

@places = []
if OPTS.place_ids
  place_ids = OPTS.place_ids.split( "," )
  place_ids.each do |place_id|
    if place = Place.find_by_id( place_id )
      @places << place
    else
      Optimist::die "Couldn't find place with ID #{place_id}"
    end
  end
  @places = @places.sort_by(&:display_name)
end

headers = %w(
  email
  name
  login
  locale
  site_id
  site_name
  created_at_date
  last_active
  num_identifications
  num_obs
  num_obs_web
  num_obs_verifiable
)
@places.each do |place|
  header = "num_obs_#{place.display_name.parameterize.underscore.downcase}"
  headers << header
end
if OPTS.extras
  @extras = {}
  CSV.foreach( OPTS.extras, headers: true ) do |row|
    @extras[row["email"]] = row.to_h
  end
  @extra_headers = @extras.first[1].keys.sort - ["email"]
  headers += @extra_headers
end
CSV.open( @out_path, "wb" ) do |csv|
  csv << headers
  scope.script_find_each( flush: true ) do |user|
    next if @emails_to_exclude.include?( user.email )
    next if user.prefers_no_email?
    next if user.email_suppressed_in_group?( EmailSuppression::DONATION_EMAILS )
    user_count += 1
    user_filter = { term: { "user.id" => user.id } }
    num_identifications = Identification.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        user_filter,
        { term: { own_observation: false } }
      ]
    ).total_entries

    row = [
      user.email,
      user.name,
      user.login,
      user.locale,
      user.site_id,
      user.site.try(:name) || Site.default.name,
      user.created_at.to_date.to_s,
      user.last_active.to_s,
      num_identifications
    ]

    # Build aggs for all the obs counts we want so we can perform a single query
    # for this user
    obs_cols = []
    obs_aggs = {}
    obs_cols << "num_obs_web"
    obs_aggs[obs_cols.last] = {
      filter: {
        bool: { must_not: { exists: { field: "oauth_application_id" } } }
      }
    }
    obs_cols << "num_obs_verifiable"
    obs_aggs[obs_cols.last] = {
      filter: {
        terms: { quality_grade: %w(research needs_id) }
      }
    }
    @places.each do |place|
      key = "num_obs_#{place.display_name.parameterize.underscore.downcase}"
      obs_cols << key
      obs_aggs[key] = {
        filter: { terms: { private_place_ids: [place.id] } }
      }
    end
    obs_results = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        user_filter
      ],
      aggs: obs_aggs
    )
    row << obs_results.total_entries
    row += obs_cols.map{|c| obs_results.aggregations[c].doc_count}

    if @extras && extra_data = @extras[user.email]
      row += @extra_headers.map{|h| extra_data[h]}
    end

    csv << row
  end
end

puts
puts "Exported #{user_count} users in #{Time.now - start}s"
puts "Wrote #{@out_path}"
puts
