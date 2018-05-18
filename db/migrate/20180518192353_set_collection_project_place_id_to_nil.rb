class SetCollectionProjectPlaceIdToNil < ActiveRecord::Migration
  def up
    # Traditional projects converted to collections that had a place_id need it removed.
    # An "observed_in_place?" rule has already been created for the place, and these
    # projects will use rules going forward, not place_id.
    # This does mean that if the collection is converted back to a traditional project,
    # the project place would need to be set again by the owner.
    Project.where( project_type: "collection" ).
            where( "place_id IS NOT NULL" ).each do |p|
      p.update_attributes( place_id: nil )
    end
  end

  def down
    # irreversible
  end
end
