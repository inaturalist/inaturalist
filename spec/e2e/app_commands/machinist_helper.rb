# Dispatches to MakeHelpers methods for complex test data setup.
# Usage from Playwright:
#   appMachinistHelper("make_curator", { login: "curator_user" })
#   appMachinistHelper("make_research_grade_observation", { user_id: 123 })
#   appMachinistHelper("load_test_taxa", { iconic: true })

ALLOWED_METHODS = MakeHelpers.instance_methods( false ).map( &:to_s ).freeze

method_name = command_options["method"].to_s
unless ALLOWED_METHODS.include?( method_name )
  raise ArgumentError, "Unknown MakeHelpers method: #{method_name}. Allowed: #{ALLOWED_METHODS.join( ', ' )}"
end

args = command_options["args"] || {}
args = args.deep_symbolize_keys if args.is_a?( Hash )

result = if args.is_a?( Hash ) && args.any?
  send( method_name, args )
else
  send( method_name )
end

if result.respond_to?( :attributes )
  result.attributes
elsif result.respond_to?( :map ) && result.first.respond_to?( :attributes )
  result.map( &:attributes )
else
  result
end
