class ConservationStatus < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :user
  belongs_to :place
  belongs_to :source

  attr_accessible :authority, :description, :geoprivacy, :iucn, :place_id,
    :status, :taxon_id, :url, :user_id, :taxon, :user, :place, :source,
    :source_id
  validates_presence_of :status

  ["IUCN Red List", "NatureServe"].each do |authority|
    const_set authority.strip.gsub(/\s+/, '_').underscore.upcase, authority
  end

  def to_s
    "<ConservationStatus #{id} taxon: #{taxon_id} status: #{status} authority: #{authority}>"
  end

  def status_name
    case authority
    when NATURE_SERVE then nature_serve_status_name
    when IUCN_RED_LIST then iucn_name
    else 
      case status.downcase
      when 'se', 'fe', 'le', 'e' then 'endangered'
      when 'st', 'ft', 'lt', 't' then 'threatened'
      when 'sc' then 'special concern'
      when 'c' then 'candidate'
      else
        status
      end
    end
  end

  def iucn_name
    Taxon::IUCN_STATUSES[iucn.to_i].to_s.humanize.downcase
  end

  def nature_serve_status_name
    case status.scan(/\d/).to_a.min.to_i
    when 1 then "critically imperiled"
    when 2 then "imperiled"
    when 3 then "vulnerable"
    when 4 then "apparently secure"
    when 5 then "secure"
    else status
    end
  end
end
