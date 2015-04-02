Dir["#{File.dirname(__FILE__)}/elastic_model/elastic_model.rb",
    "#{File.dirname(__FILE__)}/elastic_model/acts_as_elastic_model.rb"].each { |f| load(f) }
