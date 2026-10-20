# frozen_string_literal: true

# Shared by spec_helper and the e2e server (spec/e2e/e2e_helper.rb)
def rebuild_all_test_elasticsearch_indices
  Elasticsearch::Model.client.ping
  es_classes = ApplicationRecord.descendants.filter {| m | m.respond_to?( :elastic_index! ) }
  print "Rebuilding #{es_classes.size} indexes"
  es_classes.each do | klass |
    print "."
    begin
      klass.__elasticsearch__.delete_index!
    rescue StandardError => e
      raise e unless e.class.to_s =~ /NotFound/
    end
    klass.__elasticsearch__.create_index!
    ElasticModel.wait_until_index_exists( klass.index_name, timeout: 1 )
  end
  puts
end
