# frozen_string_literal: true

module AdminHelper
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
