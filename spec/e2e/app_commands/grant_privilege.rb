# Grants a user privilege outright, bypassing the activity thresholds that normally earn it, so
# e2e specs can reach UI gated behind UserPrivilege (adding an identification needs "interaction").
#
#   app( "grant_privilege", { user_id: 1, privilege: "interaction" } )
user = User.find( command_options["user_id"] )
privilege = command_options["privilege"] || UserPrivilege::INTERACTION
UserPrivilege.where( user_id: user.id, privilege: privilege ).first_or_create!
[privilege]
