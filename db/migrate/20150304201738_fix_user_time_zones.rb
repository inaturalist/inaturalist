class FixUserTimeZones < ActiveRecord::Migration
  def up
    User.where(time_zone: "Ulaan Bataar").update_all(time_zone: "Ulaanbaatar")
    User.where(time_zone: "Kyev").update_all(time_zone: "Kyiv")
    User.where(time_zone: "").update_all(time_zone: nil)
  end

  def down
    User.where(time_zone: "Ulaanbaatar").update_all(time_zone: "Ulaan Bataar")
    User.where(time_zone: "Kyiv").update_all(time_zone: "Kyev")
  end
end
