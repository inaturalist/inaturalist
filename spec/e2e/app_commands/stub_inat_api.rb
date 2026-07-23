# Stubs INatAPIService.get_json in the running test server so pages that fetch
# JSON server-side (e.g. taxa/browse_photos, whose controller hits the node API
# before rendering) can be exercised without a live iNaturalistAPI +
# Elasticsearch. This is the server-side analog of Playwright's page.route:
# browser interception can't see a Rails-to-node-API request.
#
# Stubs match by path prefix; unmatched paths fall through to the real
# implementation via super, so unrelated API traffic is untouched.
#
#   app( "stub_inat_api", { path: "/taxa/14?", body: "{\"results\":[...]}" } )
#   app( "stub_inat_api", { reset: true, path: "/taxa/14?" } )  # drop one stub
#   app( "stub_inat_api", { reset: true } )                     # drop all stubs

module INatAPIServiceE2EStub
  def get_json( path, params = {}, options = {} )
    _prefix, body = INatAPIService.e2e_stubs.find { | prefix, _ | path.to_s.start_with?( prefix ) }
    body || super
  end
end

unless INatAPIService.respond_to?( :e2e_stubs )
  INatAPIService.define_singleton_method( :e2e_stubs ) { @e2e_stubs ||= {} }
end
unless INatAPIService.singleton_class.include?( INatAPIServiceE2EStub )
  INatAPIService.singleton_class.prepend( INatAPIServiceE2EStub )
end

if command_options["reset"]
  if command_options["path"]
    # Delete only this stub. Workers share the server process, so clearing the
    # whole registry would clobber other workers' stubs mid-run.
    INatAPIService.e2e_stubs.delete( command_options["path"] )
  else
    INatAPIService.e2e_stubs.clear
  end
else
  INatAPIService.e2e_stubs[command_options["path"]] = command_options["body"]
end

[true]
