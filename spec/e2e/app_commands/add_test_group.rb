# Adds a user to one or more test groups, bypassing model validations (some
# groups, e.g. "responsive-header", are admin-only and can't be set on a plain
# factory user). Used by e2e specs that exercise gated features.
#
#   app( "add_test_group", { user_id: 1, test_groups: "responsive-header" } )
user = User.find( command_options["user_id"] )
groups = ( user.test_groups.to_s.split( "|" ) + Array( command_options["test_groups"] ) ).uniq
user.update_column( :test_groups, groups.join( "|" ) )
[user.test_groups]
