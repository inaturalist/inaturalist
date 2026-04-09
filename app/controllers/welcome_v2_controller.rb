# frozen_string_literal: true

class WelcomeV2Controller < ApplicationController
  unless defined?( OBSERVATIONS_DATA )
    OBSERVATIONS_DATA = JSON.parse(
      File.read( Rails.root.join( "app/assets/images/welcome_v2/observations/observations.json" ) )
    ).freeze
  end

  STEPS_DATA = [
    [:observe,      "step1_body", "camera"],
    [:identify_cta, "step2_body", "identify"],
    [:contribute,   "step3_body", "globe"]
  ].freeze

  TESTIMONIALS_DATA = {
    gube: { name: "Dzivula Gube", people_path: "/people/dzivulajr_03" },
    kratzer: { name: "Chris Alice \"Alie\" Kratzer", people_path: "/people/humanbyweight" },
    sumanapala: { name: "Amila Sumanapala", people_path: "/people/amila_sumanapala" },
    fachetti: { name: "Nágyla Fachetti Coser", people_path: "/people/nah_fachetti19" },
    velazco: { name: "Carlos G. Velazco-Macias", people_path: "/people/aztekium" }
  }.freeze

  STORY_DATA = [
    ["moth_heading",      "moth_body",        "pav_johnsson", "New Zealand",  "Frosted Phoenix", "frosted_phoenix", "https://tr.ee/FYNsVb"],
    ["mantis_heading",    "mantis_body_html", "glendawalter", "Australia",    nil,               "inat",            "https://tr.ee/j29kgK"],
    ["amphibian_heading", "amphibian_body",   "tcuriel",      "United States", nil,              "california_newt", "https://tr.ee/hQZIFH"]
  ].freeze

  HEADER_UTM = "utm_source=inaturalist_homepage&utm_campaign=homepage_redesign_2026".freeze

  def index
    @responsive = true
    @skip_external_connections = true
    @skip_react = true

    @header_utm = HEADER_UTM
    @header_donate_url = "https://www.inaturalist.org/donate?redirect=true&segment=gmHome&#{HEADER_UTM}&utm_medium=webmobile&utm_content=header_donate_cta"
    @header_login_url  = "https://www.inaturalist.org/login?#{HEADER_UTM}&utm_medium=owned_web&utm_content=header_login_cta"
    @header_signup_url = "https://www.inaturalist.org/signup?#{HEADER_UTM}&utm_medium=owned_web&utm_content=header_signup_cta"

    @locale_key = I18n.locale.to_s
    @locale_base = @locale_key.split( "-" ).first

    @steps_data = STEPS_DATA
    @testimonials_data = TESTIMONIALS_DATA
    @story_data = build_story_data
    @sample_observation_data = build_sample_observation
    @explore_observations_data = OBSERVATIONS_DATA["explore"] || []

    render layout: "bootstrap"
  end

  private

  def build_story_data
    story_common_names = OBSERVATIONS_DATA["stories"] || {}
    STORY_DATA.map do |heading, body, user, place, en_name, img, url|
      # TODO: Ideally we'd use common_name to make this more generic,
      # but the translations are already using moth_common_name.
      interpolationInput = if en_name
        names = story_common_names[en_name]
        { moth_common_name: names&.dig( @locale_key ) || names&.dig( @locale_base ) || names&.dig( "en" ) || en_name }
      else
        {}
      end
      [heading, body, user, place, img, interpolationInput, url]
    end
  end

  def build_sample_observation
    observation_data = OBSERVATIONS_DATA["sample"]
    observation_data["common_name"] = observation_data["common_names"][@locale_key] ||
      observation_data["common_names"][@locale_base] ||
      observation_data["common_names"]["en"]

    observation_data
  end
end
