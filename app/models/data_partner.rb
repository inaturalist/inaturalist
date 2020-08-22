class DataPartner < ActiveRecord::Base
  WEEKLY = "weekly"
  MONTHLY = "monthly"
  FREQUENCIES = [WEEKLY, MONTHLY]

  validates :frequency, inclusion: { in: FREQUENCIES }, allow_blank: true
  validates :dwc_frequency, inclusion: { in: FREQUENCIES }, allow_blank: true

  def sync_observation_links
    # Might return an instance of something like DataPartnerLinker::Gbif which
    # knows how to use the partnership_url to configure a GBIF export we can use
    # to make obs links
    if linker = DataPartnerLinkers.linker_for( self )
      linker.run
    end
  end

  def generate_dwc
    raise "TODO"
    archive = DarwinCore::Archive.new( dwc_params )
  end

  def self.generate_dwcs
    raise "TODO"
    DataPartner.where( frequency: "weekly" ).where( "dwc_last_export_at < ?", 1.week.ago ).find_each do |dp|
      DarwinCore::Archive.generate( dp.dwc_params )
    end
    DataPartner.where( frequency: "monthly" ).where( "dwc_last_export_at < ?", 1.month.ago ).find_each do |dp|
      DarwinCore::Archive.generate( dp.dwc_params )
    end
  end
end
