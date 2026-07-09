opts = command_options.is_a?( Hash ) ? command_options.transform_keys( &:to_sym ) : {}
user = User.make!( opts )
role = Role.find_by( name: "curator" ) || Role.create!( name: "curator" )
user.roles << role
user
