class FixObservedOnDates < ActiveRecord::Migration
  def up
    Observation.where("observed_on < '1900-01-01'").update_all(
      observed_on: nil, observed_on_string: nil)
  end

  def down
    # irreversible
  end
end
