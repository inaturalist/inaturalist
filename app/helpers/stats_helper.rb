# frozen_string_literal: true

module StatsHelper
  def cohort_percent_label( percent )
    return "-" if percent.nil?

    number_to_percentage( percent.to_f * 100, precision: 1 )
  end

  def cohort_heat_color( percent )
    pct = percent.to_f.clamp( 0, 1 )
    lightness = 92 - ( pct * 55 )
    "hsl( 105, 60%, #{lightness}% )"
  end

  def cohort_text_color( percent )
    pct = percent.to_f.clamp( 0, 1 )
    lightness = 92 - ( pct * 55 )
    ( lightness < 55 ) ? "#ffffff" : "#1f2a44"
  end

  def cohort_cell_style( percent )
    "background-color: #{cohort_heat_color( percent )}; color: #{cohort_text_color( percent )};"
  end
end
