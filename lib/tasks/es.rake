require "net/http"

namespace :es do

  desc "Start elasticsearch in the background"
  task :start => :environment do
    next if fail_unless_binaries_exists
    unless elasticsearch_is_running?
      puts "\nElasticsearch is starting up...\n"
      `elasticsearch/bin/elasticsearch -d`
    end
    success = wait_until_elasticsearch_is_running
    if success
      puts "\nElasticsearch is now running at #{ elasticsearch_url }\n\n"
    else
      puts "\nElasticsearch failed to start\n\n"
    end
  end

  desc "Start elasticsearch in the forground"
  task :run => :environment do
    next if fail_unless_binaries_exists
    puts "Elasticsearch is starting at #{ elasticsearch_url } ...\n"
    puts "Kill this process to stop Elasticsearch"
    `elasticsearch/bin/elasticsearch`
  end

  desc "Stop background elasticsearch process"
  task :stop => :environment do
    next if fail_unless_binaries_exists
    `curl -XPOST #{ elasticsearch_url }/_shutdown &> /dev/null`
  end

  desc "Index all models in elasticsearch"
  task :index => :environment do
    next if fail_unless_binaries_exists
    next if fail_unless_elasticsearch_is_running
    elastic_models.each do |klass, opts|
      puts "Indexing #{klass}..."
      klass.elastic_index!(opts)
    end
  end

  desc "Delete and rebuild all models in elasticsearch"
  task :rebuild => :environment do
    next if fail_unless_binaries_exists
    next if fail_unless_elasticsearch_is_running
    elastic_models.each do |klass, opts|
      puts "Rebuilding #{klass}..."
      if klass.__elasticsearch__.client.indices.exists(index: klass.index_name)
        klass.__elasticsearch__.delete_index!
      end
      klass.__elasticsearch__.create_index!
      klass.elastic_index!(opts)
    end
  end

end

def elasticsearch_url
  Taxon.__elasticsearch__.client.transport.options[:host]
end

def elastic_models
  {
    Observation => { },
    Project => { },
    Place => { batch_size: 20 },
    Taxon => { }
  }
end

def binary_path
  Rails.root.join("elasticsearch", "bin", "elasticsearch")
end

def binaries_exist
  File.exists?(binary_path)
end

def fail_unless_binaries_exists
  unless binaries_exist
    puts "\nUnable to locate binary #{ binary_path }.\n"
    puts "Please refer to the iNaturalist development detup guide:\n"
    puts "    https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide\n\n"
    return true
  end
  return false
end

def elasticsearch_is_running?
  begin
    response = Net::HTTP.get(URI.parse(elasticsearch_url))
    return JSON.parse(response)["status"] == 200
  rescue
  end
  return false
end

def fail_unless_elasticsearch_is_running
  unless elasticsearch_is_running?
    puts "\nElasticsearch is not running. You might want to run `rake es:start`\n\n"
    return true
  end
  return false
end

def wait_until_elasticsearch_is_running(options={})
  options[:timeout] ||= 10
  start_time = Time.now
  while !elasticsearch_is_running? && (Time.now - start_time <= options[:timeout])
    sleep(1)
  end
  return elasticsearch_is_running?
end
