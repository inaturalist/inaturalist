# frozen_string_literal: true

class AddGbifDataPartner < ActiveRecord::Migration[6.1]
  def up
    # Name must be exactly "GBIF" to match DataPartnerLinkers.linker_for.
    # Monthly frequency so DataPartner.sync_observation_links schedules it.
    DataPartner.find_or_create_by!( name: "GBIF" ) do | dp |
      dp.url = "https://www.gbif.org"
      dp.description = "Global Biodiversity Information Facility"
      dp.frequency = DataPartner::MONTHLY
    end
  end

  def down
    DataPartner.where( name: "GBIF" ).destroy_all
  end
end
