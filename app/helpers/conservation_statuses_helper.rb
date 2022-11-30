# frozen_string_literal: true

module ConservationStatusesHelper
  def iucn_status_select_options
    Taxon::IUCN_STATUS_NAMES.map do | status_name |
      ["#{I18n.t( status_name, default: status_name ).humanize} (#{Taxon::IUCN_STATUS_CODES[status_name]})",
       Object.const_get( "Taxon::IUCN_#{status_name.upcase}" )]
    end
  end
end
