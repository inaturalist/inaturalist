require 'test/unit'
require "rubygems"
require 'active_support'
require "erb"
require "ostruct"
# render the RoleRequirementSystem template and "eval it"

def render_template_with_locals(abs_name, locals = {})
  template = File.read(File.join( abs_name) )
  ERB.new(template, nil, "-").result(OpenStruct.new(locals).send(:binding))
end

def include_rendered_template(abs_name, locals = {})
  code = render_template_with_locals(abs_name, locals)
  eval(code, binding, abs_name, 1)
end

include_rendered_template(
  File.join( File.dirname(__FILE__), "../generators/roles/templates/role_requirement_system.rb.erb"), 
  {:users_name => "user" }
)

%w[authenticated_system controller_stub.rb user_stub.rb].each { |file| require File.expand_path(File.join(File.dirname(__FILE__), file)) }
