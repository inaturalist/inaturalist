require File.expand_path(File.dirname(__FILE__) + "/lib/insert_routes.rb")
class ForgotPasswordGenerator < Rails::Generator::NamedBase
                  
  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_singular_name,
                :controller_plural_name,
                :controller_file_name,
                :user_model_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super
    
    @rspec = has_rspec?

    @user_model_name = (args.shift || 'user')
    @controller_name = @name.pluralize || 'passwords'
    
    # sessions controller
    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_file_name, @controller_plural_name = inflect_names(base_name)
    @controller_singular_name = @controller_file_name.singularize

    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end

  end

  def manifest
    recorded_session = record do |m|
      # Check for class naming collisions.
      m.class_collisions controller_class_path,       "#{controller_class_name}Controller", # Sessions Controller
                                                      "#{controller_class_name}Helper"
      m.class_collisions class_path,                  "#{class_name}", "#{class_name}Mailer", "#{class_name}MailerTest", "#{class_name}Observer"
      m.class_collisions [], 'AuthenticatedSystem', 'AuthenticatedTestHelper'

      # Controller, helper, views, and test directories.
      m.directory File.join('app/models', class_path)
      m.directory File.join('app/controllers', controller_class_path)
      m.directory File.join('app/helpers', controller_class_path)
      m.directory File.join('app/views', controller_class_path, controller_file_name)
      m.directory File.join('app/views', class_path, "#{file_name}_mailer")


      m.template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")

      m.template 'mailer.rb',
                  File.join('app/models', class_path, "#{file_name}_mailer.rb")

      m.template 'controller.rb',
                  File.join('app/controllers',
                            controller_class_path,
                            "#{controller_file_name}_controller.rb")

      m.template 'helper.rb',
                  File.join('app/helpers',
                            controller_class_path,
                            "#{controller_file_name}_helper.rb")

      # Controller templates
      m.template 'new.html.erb',  File.join('app/views', controller_class_path, controller_file_name, "new.html.erb")
      m.template 'reset.html.erb',  File.join('app/views', controller_class_path, controller_file_name, "reset.html.erb")

      unless options[:skip_migration]
        m.migration_template 'migration.rb', 'db/migrate', :assigns => {
          :migration_name => "Create#{class_name.pluralize.gsub(/::/, '')}"
        }, :migration_file_name => "create_#{file_path.gsub(/\//, '_').pluralize}"
      end

      # if options[:include_activation]
        # Mailer templates
        %w( forgot_password reset_password ).each do |action|
          m.template "#{action}.html.erb",
                     File.join('app/views', "#{file_name}_mailer", "#{action}.html.erb")
        end
      # end

      m.route_resources  controller_plural_name
      m.route_name('change_password', '/change_password/:reset_code', { :controller => controller_plural_name, :action => 'reset' })
      m.route_name('forgot_password', '/forgot_password', { :controller => controller_plural_name, :action => 'new' })

    end

    action = nil
    action = $0.split("/")[1]
    case action
      when "generate" 
        puts
        # puts ("-" * 70)
        # puts "Don't forget to add this to config/routes.rb:"
        # puts
        # puts %(map.change_password '/change_password/:reset_code', :controller => 'passwords', :action => 'reset')
        # puts
        # puts ("-" * 70)
        puts
      when "destroy" 
        puts
        puts ("-" * 70)
        puts
        puts "Thanks for using forgot_password"
        puts
        puts "Don't forget to remove this from config/routes.rb (if it's there):"
        puts
        puts %(map.change_password '/change_password/:reset_code', :controller => 'passwords', :action => 'reset')
        puts
        puts ("-" * 70)
        puts
      else
        puts
    end

    recorded_session
  end

  def has_rspec?
    options[:rspec] || (File.exist?('spec') && File.directory?('spec'))
  end
  
  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} forgot_password ModelName UserModelName"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
    end
end
