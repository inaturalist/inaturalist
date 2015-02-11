require 'rubygems'
require 'trollop'

@opts = Trollop::options do
    banner <<-EOS
Create ObservationLinks for observations that have been integrated into GBIF.

Usage:

  rails runner tools/gbif_observation_links.rb

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :username, "GBIF username", :type => :string, :short => "-u", :default => CONFIG.gbif.try(:username)
  opt :password, "GBIF password", :type => :string, :short => "-p", :default => CONFIG.gbif.try(:password)
  opt :notification_address, "Email address to receive GBIF notification", :type => :string, :short => "-e", :default => CONFIG.gbif.try(:notification_address)
  opt :request_key, "GBIF download request key", :type => :string, :short => "-k"
  # opt :last_interpreted, "Filter results"
end

Trollop::die "You must specify a GBIF username" if @opts.username.blank?
Trollop::die "You must specify a GBIF password" if @opts.password.blank?

start_time = Time.now
new_count = 0
old_count = 0
delete_count = 0
count = 0

def system_call(cmd)
  puts "Running #{cmd}"
  system cmd
  puts
end

def request
  if @opts.request_key
    @key = @opts.request_key
    return
  end
  url = "http://#{@opts.username}:#{@opts.password}@api.gbif.org/v1/occurrence/download/request"
  json = {
    :creator => @opts.username,
    :notification_address => [@opts.notification_address],
    :predicate => {
      :type => "and",
      :predicates => [
        {
          :type => "equals",
          :key => "INSTITUTION_CODE",
          :value => "iNaturalist"
        }
        # {
        #   :type => "equals",
        #   :key => "TAXON_KEY",
        #   :value => 3189179
        # }
      ]
    }
  }.to_json
  puts "Requesting #{url}" if @opts.debug
  puts "With JSON: #{json}" if @opts.debug
  @key = RestClient.post url, json, :content_type => :json, :accept => :json
  puts "Received key: #{@key}" if @opts[:debug]
end

def generating
  zip_url = "http://api.gbif.org/v0.9/occurrence/download/request/#{@key}.zip"
  status_url = "http://api.gbif.org/v0.9/occurrence/download/#{@key}"
  @num_checks ||= 0
  puts "Checking #{status_url}" if @opts.debug && @num_checks == 0
  # begin
  #   RestClient.head url
  #   @num_checks += 1
  # rescue RestClient::ResourceNotFound => e
  #   return true
  # rescue RestClient::InternalServerError => e
  #   Trollop::die "Looks like a bug at GBIF: #{e}"
  # end
  @status = JSON.parse(RestClient.get(status_url))
  @num_checks += 1
  @status['status'] != 'SUCCEEDED'
end

def download
  url = "http://api.gbif.org/v0.9/occurrence/download/request/#{@key}.zip"
  filename = File.basename(url)
  @tmp_path = File.join(Dir::tmpdir, "#{File.basename(__FILE__, ".*")}-#{@key}")
  archive_path = "#{@tmp_path}/#{filename}"
  work_path = @tmp_path
  FileUtils.mkdir_p @tmp_path, :mode => 0755
  unless File.exists?("#{@tmp_path}/#{filename}")
    system_call "curl -o #{@tmp_path}/#{filename} #{url}"
  end
  system_call "unzip -d #{@tmp_path} #{@tmp_path}/#{filename}"
end

request
puts "Waiting for archive to generate..."
while generating
  print '.'
  sleep 3
end
puts
puts "Downloading archive..."
download
CSV.foreach(File.join(@tmp_path, "occurrence.txt"), :col_sep => "\t", :headers => true) do |row|
  # puts "row['gbifID']: #{row['gbifID']}\t\trow['catalogNumber']: #{row['catalogNumber']}"
  observation_id = row['catalogNumber']
  gbif_id = row['gbifID']
  puts [
    gbif_id.to_s.ljust(20), 
    "#{count} of #{@status['totalRecords']} (#{(count / @status['totalRecords'].to_f * 100).round(2)}%)".ljust(30),
    "#{((Time.now - start_time) / 60.0).round(2)} mins"
    ].join(' ')
  observation = Observation.find_by_id(observation_id)
  if observation.blank?
    puts "\tobservation #{observation_id} doesn't exist, skipping..."
    next
  end
  href = "http://www.gbif.org/occurrence/#{gbif_id}"
  existing = ObservationLink.where(observation_id: observation_id, href: href).first
  if existing
    existing.touch unless @opts[:debug]
    old_count += 1
    puts "\tobservation link already exists for observation #{observation_id}, skipping"
  else
    ol = ObservationLink.new(:observation => observation, :href => href, :href_name => "GBIF", :rel => "alternate")
    ol.save unless @opts[:debug]
    new_count += 1
    # puts "\tCreated #{ol}"
  end
  count += 1
end

delete_count = ObservationLink.where(href_name: "GBIF").where("updated_at < ?", start_time).count
ObservationLink.delete_all(["href_name = 'GBIF' AND updated_at < ?", start_time]) unless @opts[:debug]
puts "#{new_count} created, #{old_count} updated, #{delete_count} deleted in #{Time.now - start_time} s. Request key: #{@key}"
