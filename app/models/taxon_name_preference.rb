class TaxonNamePreference < ApplicationRecord
  belongs_to :user
  belongs_to :place

  validates_presence_of :user_id
  validates_presence_of :position
  validates_uniqueness_of :lexicon, scope: [:user_id, :place_id]
  validates_uniqueness_of :position, scope: [:user_id]

  before_validation :set_position

  def set_position
    highest_user_position = TaxonNamePreference.where( user: user ).maximum( :position )
    self.position ||= highest_user_position ? highest_user_position + 1 : 0
  end

  def self.populate
    User.where( "place_id IS NOT NULL" ).find_in_batches do |batch|
      TaxonNamePreference.transaction do
        batch.each do |u|
          TaxonNamePreference.create(
            user: u,
            lexicon: ( TaxonName::LEXICONS_BY_LOCALE[u.locale] || TaxonName::ENGLISH ).parameterize,
            place_id: u.place_id,
            position: 0
          )
        end
      end
    end
  end
end
