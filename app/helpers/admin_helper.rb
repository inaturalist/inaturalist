# frozen_string_literal: true

module AdminHelper
  # The iNat Queries page exists only where the sessions it lists exist, which
  # in practice means staging. Leaving these unset hides it entirely
  def inat_queries_enabled?
    CONFIG.inat_usename.present? && CONFIG.inat_client_addr.present?
  end

  def human_duration( duration_ms )
    if duration_ms < 1000
      "#{duration_ms.round} ms"
    elsif duration_ms < 60_000
      "#{( duration_ms / 1000.0 ).round( 2 )} s"
    else
      minutes = ( duration_ms / 60_000 ).floor
      seconds = ( ( duration_ms % 60_000 ) / 1000.0 ).round( 2 )
      "#{minutes} min #{seconds} s"
    end
  end
end
