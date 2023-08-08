class TaxonNamePriority < ApplicationRecord
  belongs_to :user
  belongs_to :place

  validates_presence_of :user_id
  validates_presence_of :position
  validates_uniqueness_of :lexicon, scope: [:user_id, :place_id]
  validates_uniqueness_of :position, scope: [:user_id]

  before_validation :set_position

  def set_position
    highest_user_position = TaxonNamePriority.where( user: user ).maximum( :position )
    self.position ||= highest_user_position ? highest_user_position + 1 : 0
  end

  def update_position( new_position )
    return if !new_position
    return if new_position == position
    original_position = position
    highest_user_position = TaxonNamePriority.where( user: user ).maximum( :position )
    # temporarily set the position of this record to one more than the last position
    # to make room for moving displaced records to avoid a uniqueness constraint
    update( { position: highest_user_position + 1 } )
    base_update_scope = TaxonNamePriority.where( user: user ).where( "id != ?", id )
    if new_position < original_position
      # moving this entry up
      next_position = original_position
      # starting from this record's original position and working up to the new position,
      # decrement the displaced records position by one - moving them each down one
      base_update_scope.where( "position < ? AND position >= ?", original_position, new_position ).order( position: :desc ).each do |affected_record|
        affected_record.update( position: next_position )
        next_position -= 1
      end
    else
      # moving this record down
      next_position = original_position
      # starting from this record's original position and working down to the new position,
      # increment the displaced records position by one - moving them each up one
      base_update_scope.where( "position > ? AND position <= ?", original_position, new_position ).order( position: :asc ).each do |affected_record|
        affected_record.update( position: next_position )
        next_position += 1
      end
    end
    # set the actual new position of this record now that the displaced records
    # have been updated and there will not be any position uniqueness conflict
    update( { position: new_position } )
  end

  # for all users that have a preferred place setting, which affects common name localization,
  # create a new TaxonNamePriority for that place with a nil lexicon. That will maintain
  # the preferred place and common names shown will match the user's locale setting
  def self.populate
    return if TaxonNamePriority.any?
    User.where( "place_id IS NOT NULL" ).find_in_batches do |batch|
      TaxonNamePriority.transaction do
        batch.each do |u|
          TaxonNamePriority.create(
            user: u,
            lexicon: nil,
            place_id: u.place_id,
            position: 0
          )
        end
      end
    end
  end
end
