#encoding: utf-8
class ConservationStatus < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :user
  belongs_to :place
  belongs_to :source

  before_save :set_geoprivacy
  after_save :update_observation_geoprivacies, :if => lambda {|record|
    record.id_changed? || record.geoprivacy_changed?
  }
  after_save :update_taxon_conservation_status
  after_destroy :update_observation_geoprivacies
  after_destroy :update_taxon_conservation_status

  attr_accessor :skip_update_observation_geoprivacies
  validates_presence_of :status, :iucn
  validates_uniqueness_of :authority, :scope => [:taxon_id, :place_id], :message => "already set for this taxon in that place"

  scope :for_taxon, lambda {|taxon| where(:taxon_id => taxon)}
  scope :for_lat_lon, lambda {|lat,lon|
    joins("JOIN place_geometries ON place_geometries.place_id = conservation_statuses.place_id").
    where("ST_Intersects(place_geometries.geom, ST_Point(?, ?))", lon, lat)
  }

  ["IUCN Red List", "NatureServe", "Norma Oficial 059"].each do |authority|
    const_set authority.strip.gsub(/\s+/, '_').underscore.upcase, authority
  end

  def to_s
    "<ConservationStatus #{id} taxon: #{taxon_id} place: #{place_id} status: #{status} authority: #{authority}>"
  end

  def status_name
    case authority
    when NATURE_SERVE
      nature_serve_status_name
    when IUCN_RED_LIST
      if iucn == Taxon::IUCN_LEAST_CONCERN
        "of least concern"
      else
        iucn_name
      end
    when NORMA_OFICIAL_059
      norma_oficial_059_status_name
    else 
      case status.downcase
      when 'se', 'fe', 'le', 'e' then 'endangered'
      when 'st', 'ft', 'lt', 't' then 'threatened'
      when 'sc' then 'special concern'
      when 'c' then 'candidate'
      else
        if !description.blank? && description.to_s.size < 50
          "#{description} (#{status})"
        else
          status
        end
      end
    end
  end

  def iucn_name
    iucn_status.humanize.downcase
  end

  def iucn_status
    Taxon::IUCN_STATUSES[iucn.to_i].to_s
  end

  def iucn_status_code
    Taxon::IUCN_STATUS_CODES[Taxon::IUCN_STATUSES[iucn.to_i]]
  end

  def nature_serve_status_name
    ns_status = status[/T(.)/, 1] || status[1]
    case ns_status
    when "X" then "extinct"
    when "H" then "possibly extinct"
    when "1" then "critically imperiled"
    when "2" then "imperiled"
    when "3" then "vulnerable"
    when "4" then "apparently secure"
    when "5" then "secure"
    else status
    end
  end

  def norma_oficial_059_status_name
    norma_status = status
    case norma_status
    when "P" then "en peligro de extinción"
    when "A" then "amenazada"
    when "Pr" then "sujeta a protección especial"
    when "Ex" then "probablemente extinta en el medio silvestre"
    else status
    end
  end

  def set_geoprivacy
    self.geoprivacy = nil if geoprivacy.blank?
    true
  end

  def update_observation_geoprivacies
    return true if skip_update_observation_geoprivacies
    Observation.delay(:priority => USER_INTEGRITY_PRIORITY).
      reassess_coordinates_for_observations_of(taxon_id, :place => place_id)
    true
  end

  def update_taxon_conservation_status
    Taxon.set_conservation_status(taxon_id)
  end
end
