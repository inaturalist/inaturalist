module RoleGeneratorHelpers
  def insert_content_after(filename, regexp, content_for_insertion, options = {})
    content = File.read(filename)
    options[:unless] ||= lambda {false }
    # already have the function?  Don't generate it twice
    unless options[:unless].call(content)
      # find the line that has the model declaration
      lines = content.split("\n")
      found_line = nil
      
      0.upto(lines.length-1) {|line_number| 
        found_line = line_number if regexp.match(lines[line_number])
      }
      if found_line
        # insert the rest of these lines after the found line
        lines.insert(found_line+1, content_for_insertion)
        content = lines * "\n"
        
        File.open(filename, "w") {|f| f.puts content }
        return true
      end
    else
      return false
    end
  end
  
  def add_role_requirement_system(m)
    m.template 'role_requirement_system.rb.erb',
          File.join('lib', "role_requirement_system.rb")
    m.template 'role_requirement_test_helper.rb.erb',
          File.join('lib', "role_requirement_test_helper.rb")
    m.template 'hijacker.rb',
          File.join('lib', "hijacker.rb")
  end
  
  def add_dependencies_to_test_helper_rb
    app_filename = "#{RAILS_ROOT}/test/test_helper.rb"
    
    test_helper_content = <<EOF
  # RoleRequirementTestHelper must be included to test RoleRequirement
  include RoleRequirementTestHelper
EOF
    insert_content_after(
      app_filename, 
      /class +Test::Unit::TestCase/, 
      test_helper_content,
      :unless => lambda {|content| /include +RoleRequirementTestHelper/.match(content) }
    ) && puts("Added RoleRequirementTestHelper include to #{app_filename}")
  end

  def add_dependencies_to_application_rb
    app_filename = "#{RAILS_ROOT}/app/controllers/application.rb"
    
    auth_system_content = <<EOF
  # AuthenticatedSystem must be included for RoleRequirement, and is provided by installing acts_as_authenticates and running 'script/generate authenticated account user'.
  include AuthenticatedSystem
EOF
    
    role_requirement_content = <<EOF
  # You can move this into a different controller, if you wish.  This module gives you the require_role helpers, and others.
  include RoleRequirementSystem
EOF

    insert_content_after(
      app_filename, 
      /class +ApplicationController/, 
      auth_system_content,
      :unless => lambda {|content| /include +AuthenticatedSystem/.match(content) }
    ) && puts("Added ApplicationController include to #{app_filename}")
    
    insert_content_after(
      app_filename, 
      /include +AuthenticatedSystem/, 
      role_requirement_content,
      :unless => lambda {|content| /include +RoleRequirementSystem/.match(content) }
    ) && puts("Added RoleRequirement include to #{app_filename}")
    
  end
  
  def users_model_filename;  "app/models/#{users_model_name.underscore}.rb"; end;
    
  def users_name;  "#{users_model_name.downcase}"; end;
  
end