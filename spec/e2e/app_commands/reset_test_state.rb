# Resets the test DB and ES indexes to the state CI starts from (db:setup + es:rebuild).
# Locally, inaturalist_test and the test_* indexes are shared with rspec and the
# iNaturalistAPI suite, which loads fixtures with explicit ids without advancing
# sequences and deletes every test_* index when it finishes. Running this wipes
# any of those suites running concurrently, so don't overlap them.
#
#   app( "reset_test_state" )
DatabaseCleaner.clean_with( :truncation, { except: %w(spatial_ref_sys) } )
rebuild_all_test_elasticsearch_indices
["ok"]
