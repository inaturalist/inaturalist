# The Friendship blueprint builds its own users, so machinist can't link existing ones.
#
#   app( "follow", { user_id: 1, friend_id: 2 } )
friendship = Friendship.create!( user_id: command_options["user_id"], friend_id: command_options["friend_id"] )
[friendship.id]
