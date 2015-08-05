require 'rubygems'
require 'trollop'

OPTS = Trollop::options do
    banner <<-EOS
Export an archive for a particular site within this installation. The archive
can be into an empty database with import_site_archive.rb. This is basically a
command script that runs a bunch of psql statements, so check the log to make
sure they work. It will just run and zip up the results regardless.

Usage:

  rails runner tools/export_site_archive.rb SITE_NAME

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :file, "Where to write the archive. Default will be tmp path.", :type => :string, :short => "-f"
  opt :site_name, "Site name", type: :string, short: "-s"
  opt :site_id, "Site ID", type: :string, short: "-i"
end

start_time = Time.now
@site_name = OPTS.site_name || ARGV[0]
puts "@site_name: #{@site_name}"
puts "ARGV: #{ARGV.inspect}"
puts "OPTS: #{OPTS.inspect}"
@site = Site.find_by_name(@site_name)
@site ||= Site.find_by_id(OPTS.site_id)
unless @site
  Trollop::die "No site with name '#{@site_name}'"
end
@site_name = @site.name

@work_path = Dir.mktmpdir
FileUtils.mkdir_p @work_path, :mode => 0755
@basename = "#{@site_name}-#{Date.today.to_s.gsub(/\-/, '')}-#{Time.now.to_i}"

def system_call(cmd)
  puts "Running #{cmd}" if OPTS[:debug]
  system cmd
end

def make_archive(*args)
  fname = "#{@basename}.zip"
  tmp_path = File.join(@work_path, fname)
  fnames = args.map{|f| File.basename(f)}
  system_call "cd #{@work_path} && zip -D #{tmp_path} #{fnames.join(' ')}"
  tmp_path
end

def export_model(klass)
  # sort the column names to prevent conflict btwn databases with different column orders
  select = klass.column_names.sort.map{|c| "#{klass.table_name}.#{c}"}.join(',')
  select = "DISTINCT ON (#{klass.table_name}.id) #{select}" if klass.column_names.include?('id')
  scope = klass.select(select)
  if klass.column_names.include?('site_id')
    puts "Exporting #{@site_name} #{klass.name.underscore.pluralize}" if OPTS[:debug]
    scope = scope.where("#{klass.table_name}.site_id = ?", @site)

  # model-specific stuff
  elsif klass == ListedTaxon
    puts "Exporting listed_taxa on lists belonging to users of #{@site_name}" if OPTS[:debug]
    scope = scope.joins(:list => :user).where("users.site_id = ?", @site)
  elsif klass == ObservationField
    puts "Exporting observation_fields used in observations of #{@site_name}" if OPTS[:debug]
    scope = scope.joins(:observation_field_values => :observation).where("observations.site_id = ?", @site)
  elsif klass.reflections.detect{|k,v| k == :guide}
    puts "Exporting #{klass.name.underscore.pluralize} belonging to users of #{@site_name}" if OPTS[:debug]
    klass.joins(:guide => :user).where("users.site_id = ?", @site)
  elsif klass == Photo
    puts "Exporting #{klass.name.underscore.pluralize} belonging to observations of #{@site_name} or taxa" if OPTS[:debug]
    # klass.joins({:observation_photos => :observation}, :taxon_photos).where("observations.site_id = ? OR taxon_photos.id IS NOT NULL", @site)
    scope = scope.
      joins("LEFT OUTER JOIN observation_photos op ON op.photo_id = photos.id").
      joins("LEFT OUTER JOIN observations o ON op.observation_id = o.id").
      joins("LEFT OUTER JOIN taxon_photos tp ON tp.photo_id = photos.id").
      where("o.site_id = ? OR tp.id IS NOT NULL", @site)
  elsif klass == Project
    scope = scope.joins(:project_users => :user).where("users.site_id = ?", @site)
  elsif klass == Place
    puts "Exporting places created by, subscribed to by, and user in projects by users of #{@site_name}" if OPTS[:debug]
    scope = scope.
      joins(:user).
      joins("LEFT OUTER JOIN projects ON projects.place_id = places.id").
      joins("LEFT OUTER JOIN users pusers on pusers.id = projects.user_id").
      joins("LEFT OUTER JOIN subscriptions ON subscriptions.resource_type = 'Place' AND subscriptions.resource_id = places.id").
      joins("LEFT OUTER JOIN users subscription_users ON subscriptions.user_id = subscription_users.id").
      joins("LEFT OUTER JOIN rules ON rules.operand_type = 'Place' AND rules.operand_id = places.id").
      joins("LEFT OUTER JOIN projects rule_projects ON rules.ruler_type = 'Project' AND rules.ruler_id = projects.id").
      joins("LEFT OUTER JOIN users rule_project_users ON rule_projects.user_id = rule_project_users.id").
      where("users.site_id = ? OR pusers.site_id = ? OR subscription_users.site_id = ? OR rule_project_users.id = ?", @site, @site, @site, @site)
  elsif klass == PlaceGeometry
    puts "Exporting place_geometries for places created by, subscribed to by, and user in projects by users of #{@site_name}" if OPTS[:debug]
    scope = scope.
      joins(:place => :user).
      joins("LEFT OUTER JOIN projects ON projects.place_id = places.id").
      joins("LEFT OUTER JOIN users pusers on pusers.id = projects.user_id").
      joins("LEFT OUTER JOIN subscriptions ON subscriptions.resource_type = 'Place' AND subscriptions.resource_id = places.id").
      joins("LEFT OUTER JOIN users subscription_users ON subscriptions.user_id = subscription_users.id").
      joins("LEFT OUTER JOIN rules ON rules.operand_type = 'Place' AND rules.operand_id = places.id").
      joins("LEFT OUTER JOIN projects rule_projects ON rules.ruler_type = 'Project' AND rules.ruler_id = projects.id").
      joins("LEFT OUTER JOIN users rule_project_users ON rule_projects.user_id = rule_project_users.id").
      where("users.site_id = ? OR pusers.site_id = ? OR subscription_users.site_id = ? OR rule_project_users.id = ?", @site, @site, @site, @site)

  # anything else including a user_id or observation_id
  elsif klass.column_names.include?('user_id')
    puts "Exporting #{klass.name.underscore.pluralize} belonging to users of #{@site_name}" if OPTS[:debug]
    scope = scope.joins(:user).where("users.site_id = ?", @site)
  elsif klass.column_names.include?('observation_id')
    puts "Exporting #{klass.name.underscore.pluralize} belonging to observations of #{@site_name}" if OPTS[:debug]
    scope = scope.joins(:observation).where("observations.site_id = ?", @site)

  else
    # dump everything for the rest
  end
  table_export_path = File.join(@work_path, "#{klass.table_name}.csv")
  sql = "COPY (#{scope.to_sql}) TO STDOUT WITH CSV HEADER"
  connection = ActiveRecord::Base.connection
  db_config = Rails.configuration.database_configuration[Rails.env]
  cmd = "psql #{connection.current_database}"
  cmd += " -h #{db_config['host']}" if db_config['host']
  cmd += " -U #{db_config['username']}" if db_config['username']
  cmd += " -c \"#{sql}\" > #{table_export_path}"
  system_call cmd.gsub(/\s+/m, ' ')
  table_export_path
end

paths = []
Rails.application.eager_load!
ActiveRecord::Base.descendants.sort_by(&:name).each do |klass|
  # try to ignore 3rd party stuff
  next if klass.name =~ /(Doorkeeper|Delayed|Thinking|\:\:|DeletedUser|DeletedObservation)/

  # ignore weird HABTM stuff
  next if klass.name =~ /HABTM_/i

  # ignore STI descendants
  next if klass != List && klass.ancestors.include?(List)
  next if klass != Photo && klass.ancestors.include?(Photo)
  next if klass != Sound && klass.ancestors.include?(Sound)
  next if klass != Post && klass.ancestors.include?(Post)
  next if klass != TaxonChange && klass.ancestors.include?(TaxonChange)
  next if klass != FlowTask && klass.ancestors.include?(FlowTask)
  next if klass != Rule && klass.ancestors.include?(Rule)
  next if [
    DeletedObservation, # irrelevant
    Update, # massive
    FlowTask, # irrelevant
    TaxonRange # massive
  ].include?(klass)

  # test
  # next if [Photo, Taxon, ListedTaxon, ProjectObservation].include?(klass)

  puts
  puts klass.name.underscore.humanize.upcase
  if path = export_model(klass)
    paths << path
  end
end
archive_path = make_archive(*paths)
if OPTS[:file]
  system_call("mv #{archive_path} #{OPTS[:file]}")
  archive_path = OPTS[:file]
end

puts "Exported #{archive_path} in #{Time.now - start_time} s"
