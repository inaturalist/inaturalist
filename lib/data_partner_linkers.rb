module DataPartnerLinkers
  def self.linker_for( data_partner, options = {} )
    case data_partner.name
    when "GBIF" then DataPartnerLinkers::GBIF.new( data_partner, options )
    when "Maryland Biodiversity Project" then DataPartnerLinkers::MarylandBiodiversityProject.new( data_partner, options )
    when "Calflora" then DataPartnerLinkers::Calflora.new( data_partner, options )
    end
  end

  # Creats ObservationLinks for a DataPartner. This is basically an interface
  # with some barebones scaffolding. Actual linker classes will need to
  # implement the run method
  class DataPartnerLinker
    def initialize( data_partner, options = {} )
      @data_partner = data_partner
      @logger = options[:logger]
      @opts = options
    end

    def logger
      @logger ||= Rails.logger
    end

    def system_call(cmd)
      logger.info "[#{Time.now}] Running #{cmd}"
      system cmd
      logger.info
    end

    def run
      raise "You need to implement this in your subclass!"  
    end
  end

  class DataPartnerLinkerError < StandardError; end
end
