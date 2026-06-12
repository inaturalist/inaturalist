DatabaseCleaner.clean_with( :truncation, except: %w[taxa taxon_names] )
Taxon.reset_iconic_taxa_constants_for_tests
