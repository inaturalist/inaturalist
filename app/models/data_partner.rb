class DataPartner < ApplicationRecord
  UNKNOWN = "unknown"
  DAILY = "daily"
  WEEKLY = "weekly"
  MONTHLY = "monthly"
  FREQUENCIES = [UNKNOWN, DAILY, WEEKLY, MONTHLY]

  if CONFIG.usingS3
    has_attached_file :logo,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "data_partners/:id-logo.:extension",
      url: ":s3_alias_url"
    invalidate_cloudfront_caches :logo, "data_partners/:id-logo.*"
  else
    has_attached_file :logo,
      path: ":rails_root/public/attachments/data_partners/:id-logo.:extension",
      url: "/attachments/data_partners/:id-logo.:extension"
  end
  validates_attachment_content_type :logo, content_type: [/jpe?g/i, /png/i, /gif/i, /octet-stream/, /svg/], 
    message: "must be JPG, PNG, SVG, or GIF"

  validates :frequency, inclusion: { in: FREQUENCIES }, allow_blank: true
  validate :dwca_frequency_allowed
  validates :name, presence: true
  validates :url, presence: true
  validates :description, presence: true

  def to_s
    "<DataPartner #{id} #{name}>"
  end

  def dwca_frequency_allowed
    if dwca_params && !dwca_params["freq"].blank? && !FREQUENCIES.include?( dwca_params["freq"] )
      errors.add( :dwca_params, "freq must be one of #{FREQUENCIES.join( ", " )}")
    end
  end

  def sync_observation_links( options = {} )
    # TODO try to avoid reindexing obs when running each linker and instead
    # maybe pluck all obs IDs from obs links updated in this run and reindex
    # them at the end
    if linker = DataPartnerLinkers.linker_for( self, options )
      linker.run
      update!( last_sync_observation_links_at: Time.now )
    end
  end

  def generate_dwca( options = {} )
    params = dwca_params.clone
    params[:logger] = options[:logger] unless options[:logger].blank?
    DarwinCore::Archive.generate( params )
    update!( dwca_last_export_at: Time.now )
  end

  def self.sync_observation_links( options = {} )
    logger = options[:logger] || Rails.logger
    start = Time.now
    logger.info "DataPartner.sync_observation_links START"
    block = Proc.new do |dp|
      logger.info "DataPartner.sync_observation_links  for #{dp}"
      begin
        dp.sync_observation_links( options )
      rescue RestClient::BadRequest => e
        logger.error "Failed to sync observat links for #{dp}: #{e}"
      end
    end
    logger.info "DataPartner.sync_observation_links for monthlies and unknown frequencies"
    DataPartner.where( frequency: [MONTHLY, UNKNOWN] ).
      where( "last_sync_observation_links_at IS NULL OR last_sync_observation_links_at < ?", 1.month.ago ).
      find_each( &block )
    logger.info "DataPartner.sync_observation_links for weeklies"
    DataPartner.where( frequency: WEEKLY ).
      where( "last_sync_observation_links_at IS NULL OR last_sync_observation_links_at < ?", 1.week.ago ).
      find_each( &block )
    logger.info "DataPartner.sync_observation_links for dailies"
    DataPartner.where( frequency: DAILY ).
      where( "last_sync_observation_links_at IS NULL OR last_sync_observation_links_at < ?", 1.day.ago ).
      find_each( &block )
    logger.info "DataPartner.sync_observation_links FINISHED in #{Time.now - start}s"
  end

  def self.sync_observation_links_with_logger( logger )
    DataPartner.sync_observation_links( logger: logger )
  end

  def self.generate_dwcas( options = {} )
    logger = options[:logger] || Rails.logger
    generator = Proc.new do |dp|
      logger.info "DataPartner.generate_dwcas for #{dp}"
      begin
        dp.generate_dwca( options )
      rescue => e
        logger.error "Failed to generate DwC-A for #{dp}: #{e}"
      end
    end
    start = Time.now
    logger.info "DataPartner.generate_dwcas START"
    logger.info "DataPartner.generate_dwcas for weeklies"
    DataPartner.where( "dwca_params->>'freq' = ?", WEEKLY ).
        where( "dwca_last_export_at IS NULL OR dwca_last_export_at < ?", 1.week.ago ).
        find_each( &generator )
    logger.info "DataPartner.generate_dwcas for monthlies"
    DataPartner.where( "dwca_params->>'freq' = ?", MONTHLY ).
        where( "dwca_last_export_at IS NULL OR dwca_last_export_at < ?", 1.month.ago ).
        find_each( &generator )
    logger.info "DataPartner.generate_dwcas FINISHED in #{Time.now - start}s"
  end

  def self.generate_dwcas_with_logger( logger )
    DataPartner.generate_dwcas( logger: logger )
  end
end
