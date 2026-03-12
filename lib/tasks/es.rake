# frozen_string_literal: true

require "net/http"

namespace :es do
  desc "Start elasticsearch in the background"
  task :start => :environment do
    start
  end

  desc "Start elasticsearch in the forground"
  task :run => :environment do
    next if fail_unless_binaries_exists

    puts "Elasticsearch is starting at #{ElasticModel.elasticsearch_url} ...\n"
    puts "Kill this process to stop Elasticsearch"
    `elasticsearch/bin/elasticsearch`
  end

  desc "Stop background elasticsearch process"
  task :stop => :environment do
    stop
  end

  desc "Restart background elasticsearch process"
  task :restart => :environment do
    stop
    start
  end

  desc "Index all models in elasticsearch"
  task :index => :environment do
    next if fail_unless_binaries_exists
    next if fail_unless_elasticsearch_is_running

    elastic_models.each do | klass, opts |
      puts "Indexing #{klass}..."
      klass.elastic_index!( opts )
    end
  end

  desc "Index a single model in elasticsearch. Usage: rake es:index_model[Place,200,0.1,1,4]"
  task :index_model, [:model, :batch_size, :sleep, :part, :parts] => :environment do | _, args |
    next if fail_unless_elasticsearch_is_running

    model_name = args[:model]
    unless model_name
      puts "Missing model."
      next
    end

    klass = elastic_model_for_name( model_name )
    unless klass
      puts "Unknown model."
      next
    end

    opts = ( elastic_models[klass] || {} ).dup
    opts.merge!( elastic_index_options_from_args( args ) )
    apply_partition_options!( klass, opts, args )

    puts "Indexing #{klass}..."
    puts "Options: #{opts.inspect}" unless opts.empty?
    klass.elastic_index!( opts )
  end

  desc "Delete and recreate a single index. Usage: rake es:recreate_index[Place]"
  task :recreate_index, [:model] => :environment do | _, args |
    next if fail_unless_elasticsearch_is_running

    model_name = args[:model]
    unless model_name
      puts "Missing model."
      next
    end

    klass = elastic_model_for_name( model_name )
    unless klass
      puts "Unknown model."
      next
    end

    puts "Recreating index #{klass}..."
    client = klass.__elasticsearch__.client
    index = klass.index_name
    klass.__elasticsearch__.create_index! force: true
  end

  desc "Delete and rebuild all models in elasticsearch"
  task :rebuild => :environment do
    success = ElasticModel.wait_until_elasticsearch_is_running
    if success
      elastic_models.each do | klass, opts |
        puts "Rebuilding #{klass}..."
        if klass.__elasticsearch__.client.indices.exists( index: klass.index_name )
          klass.__elasticsearch__.delete_index!
        end
        klass.__elasticsearch__.create_index!
        klass.elastic_index!( opts )
      end
    else
      puts "\nElasticsearch failed to start\n\n"
    end
  end
end

def start
  return if fail_unless_binaries_exists

  unless ElasticModel.elasticsearch_is_running?
    puts "\nElasticsearch is starting up...\n"
    puts "elasticsearch/bin/elasticsearch -p #{pid_path} -d"
    system( "elasticsearch/bin/elasticsearch -p #{pid_path} -d" )
  end
  success = ElasticModel.wait_until_elasticsearch_is_running
  if success
    puts "\nElasticsearch is now running at #{ElasticModel.elasticsearch_url}\n\n"
  else
    puts "\nElasticsearch failed to start\n\n"
  end
end

def stop
  return if fail_unless_binaries_exists

  if File.exist?( pid_path )
    `kill \`cat #{pid_path}\``
  end
end

def elastic_models
  {
    ControlledTerm => {},
    Identification => {},
    Observation => {},
    ObservationField => {},
    Place => { batch_size: 20 },
    Project => {},
    Taxon => {},
    UpdateAction => { batch_size: 5000 },
    User => {},
    TaxonPhoto => {},
    ExemplarIdentification => {}
  }
end

def elastic_model_for_name( name )
  return if name.blank?

  elastic_models.keys.find {| klass | klass.name.casecmp( name.to_s ).zero? }
end

def elastic_index_options_from_args( args )
  opts = {}

  if args.key?( :batch_size ) && args[:batch_size].present?
    opts[:batch_size] = args[:batch_size].to_i
  end
  if args.key?( :sleep ) && args[:sleep].present?
    opts[:sleep] = args[:sleep].to_f
  end

  opts
end

def apply_partition_options!( klass, opts, args )
  part = args[:part]
  parts = args[:parts]
  return if part.nil? && parts.nil?

  part = part.to_i
  parts = parts.to_i
  raise ArgumentError, "parts must be > 0" if parts <= 0
  raise ArgumentError, "part must be between 1 and #{parts}" if part < 1 || part > parts

  min_id = klass.minimum( :id )
  max_id = klass.maximum( :id )
  unless min_id && max_id
    puts "No records to index."
    return
  end

  total = max_id - min_id + 1
  base = total / parts
  extra = total % parts
  offset = ( ( part - 1 ) * base ) + [part - 1, extra].min
  size = base + ( ( part <= extra ) ? 1 : 0 )
  start_id = min_id + offset
  end_id = start_id + size - 1

  opts[:start] = start_id
  opts[:finish] = end_id
end

def binary_path
  Rails.root.join( "elasticsearch", "bin", "elasticsearch" )
end

def binaries_exist
  File.exist?( binary_path )
end

def fail_unless_binaries_exists
  unless binaries_exist
    puts "\nUnable to locate binary #{binary_path}.\n"
    puts "Please refer to the iNaturalist development detup guide:\n"
    puts "    https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide\n\n"
    return true
  end
  false
end

def fail_unless_elasticsearch_is_running
  unless ElasticModel.elasticsearch_is_running?
    puts "\nElasticsearch is not running. You might want to run `rake es:start`\n\n"
    return true
  end
  false
end

def pid_path
  File.join( Rails.root, "tmp", "pids", "elasticsearch.pid" )
end
