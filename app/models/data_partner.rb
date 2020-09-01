class DataPartner < ActiveRecord::Base
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
  validate :dwca_frequency_allowed #, inclusion: { in: FREQUENCIES }, allow_blank: true
  validates :name, presence: true
  validates :url, presence: true
  validates :description, presence: true

  def dwca_frequency_allowed
    if dwca_params && !dwca_params["freq"].blank? && !FREQUENCIES.include?( dwca_params["freq"] )
      errors.add( :dwca_params, "freq must be one of #{FREQUENCIES.join( ", " )}")
    end
  end

  def sync_observation_links( options = {} )
    # Might return an instance of something like DataPartnerLinker::Gbif which
    # knows how to use the partnership_url to configure a GBIF export we can use
    # to make obs links
    if linker = DataPartnerLinkers.linker_for( self, options )
      linker.run
    end
  end

  def generate_dwca( options = {} )
    params = dwca_params.clone
    params[:logger] = options[:logger] unless options[:logger].blank?
    DarwinCore::Archive.generate( params )
    update_attributes!( dwca_last_export_at: Time.now )
  end

  def self.sync_observation_links( options = {} )
    DataPartner.find_each {|dp| dp.sync_observation_links( options ) }
  end

  def self.generate_dwcas( options = {} )
    logger = options[:logger] || Rails.logger
    generator = Proc.new do |dp|
      begin
        dp.generate_dwca( options )
      rescue => e
        logger.error "Failed to generate DwC-A for #{dp}: #{e}"
      end
    end
    DataPartner.where( "dwca_params->>'freq' = ?", WEEKLY ).
        where( "dwca_last_export_at IS NULL OR dwca_last_export_at < ?", 1.week.ago ).
        find_each( &generator )
    DataPartner.where( "dwca_params->>'freq' = ?", MONTHLY ).
        where( "dwca_last_export_at IS NULL OR dwca_last_export_at < ?", 1.month.ago ).
        find_each( &generator )
  end
end
