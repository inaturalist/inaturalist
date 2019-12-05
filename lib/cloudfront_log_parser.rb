class CloudfrontLogParser
  LOG_BUCKET_NAME = CONFIG.s3_cloudfront_bucket
  attr_reader :s3_client

  def initialize
    return unless LOG_BUCKET_NAME
    s3_config = YAML.load_file( File.join( Rails.root, "config", "s3.yml" ) )
    @s3_client = ::Aws::S3::Client.new(
      access_key_id: s3_config["access_key_id"],
      secret_access_key: s3_config["secret_access_key"],
      region: CONFIG.s3_region
    )
  end

  def convert_cloudfront_logs_to_logstash_format
    return unless @s3_client
    contents = @s3_client.list_objects( bucket: LOG_BUCKET_NAME ).contents
    all_but_latest_log = contents.sort_by(&:last_modified)[0...-1]
    all_but_latest_log.each do |log_object|
      download_cloudfront_log( log_object )
    end
    true
  end

  def download_cloudfront_log( log_object )
    return unless log_object && log_object.is_a?( Aws::S3::Types::Object )
    basedir = "/tmp/#{LOG_BUCKET_NAME}"
    FileUtils.mkdir_p( "/tmp/#{LOG_BUCKET_NAME}" )
    zipped_path = File.join( basedir, log_object.key )
    unzipped_path = File.join( basedir, log_object.key.sub( ".gz", "" ) )
    converted_path = File.join( basedir, log_object.key.sub( ".gz", ".json" ) )
    FileUtils.rm( zipped_path ) rescue nil
    FileUtils.rm( unzipped_path ) rescue nil
    fetched_object = s3_client.get_object( {
      bucket: LOG_BUCKET_NAME,
      key: log_object.key
    }, target: zipped_path ) rescue nil
    if fetched_object && fetched_object.body && File.exists?( zipped_path )
      system( "gunzip #{zipped_path}" )
      if File.exists?( unzipped_path )
        convert_cloudfront_log( unzipped_path, converted_path )
        if File.exists?( converted_path )
          s3_client.delete_object( bucket: LOG_BUCKET_NAME, key: log_object.key )
        end
      end
    end
    true
  end

  def parse_headers( unzipped_path )
    headers = []
    rownum = 0
    CSV.foreach( unzipped_path ) do |row|
      if rownum == 1
        headers = row[0].gsub( /#Fields:/, "" ).strip.split( " " )
      end
      break if rownum >= 1
      rownum += 1
    end
    headers
  end

  def convert_cloudfront_log( unzipped_path, converted_path )
    headers = parse_headers( unzipped_path )
    return if headers.blank?
    cloudfront_json_file = File.open( converted_path, "w" )
    CSV.foreach( unzipped_path, headers: headers, col_sep: "\t" ) do |row|
      if row["sc-bytes"] && row["c-ip"] && row["x-edge-response-result-type"] != "Error"
        size = nil
        if matches = row["cs-uri-stem"].match( /^\/photos\/[0-9]+\/([a-z]+)\./ )
          size = matches[1]
        end
        payload = {
          timestamp: "#{row['date']}T#{row['time']}Z",
          result_type: row["x-edge-response-result-type"],
          clientip: row["c-ip"],
          bytes: row["sc-bytes"].to_i,
          status_code: row["sc-status"],
          referrer: row["cs(Referer)"],
          file_path: row["cs-uri-stem"],
          image_version: size
        }
        cloudfront_json_file.write( "#{payload.to_json}\n" )
      end
    end
    cloudfront_json_file.close
    true
  end

end
