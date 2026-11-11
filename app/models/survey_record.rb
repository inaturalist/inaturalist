# frozen_string_literal: true

# Default serialization is deliberately limited
# to scalar columns: callers cannot accidentally traverse into location-bearing
# observations/sites with :include or :methods. A future authorized serializer
# must explicitly implement disclosure policy.
class SurveyRecord < ApplicationRecord
  self.abstract_class = true
  self.filter_attributes += [:geom]

  def serializable_hash( options = nil )
    options = ( options || {} ).slice( :only, :except )
    options[:except] = Array( options[:except] ) + [:geom]
    super.except( "geom" )
  end

  private

  def database_rule_valid?( function, *values )
    sql = self.class.sanitize_sql_array( ["SELECT #{function}(#{( ['?'] * values.size ).join( ',' )})", *values] )
    self.class.connection.select_value( sql )
  end
end
