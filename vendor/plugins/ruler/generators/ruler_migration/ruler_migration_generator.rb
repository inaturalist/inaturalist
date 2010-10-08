class RulerMigrationGenerator < Rails::Generator::Base
  
  def manifest
    rule_attributes = [
        %w"type string", 
        %w"ruler_type string", 
        %w"ruler_id integer", 
        %w"operand_type string", 
        %w"operand_id integer", 
        %w"operator string"].map do |name, type|
      Rails::Generator::GeneratedAttribute.new(name, type)
    end
    record do |m|
      m.migration_template 'model:migration.rb', 'db/migrate', 
        :migration_file_name => "create_rules",
        :assigns => {
          :migration_name => "CreateRules",
          :table_name => "rules",
          :attributes => rule_attributes
        }
    end
  end
  
end