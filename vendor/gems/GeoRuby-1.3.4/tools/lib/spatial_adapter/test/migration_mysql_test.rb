$:.unshift(File.dirname(__FILE__))

require 'test/unit'
require 'common/common_mysql'

class Park < ActiveRecord::Base
end

class CxGeographiclocation < ActiveRecord::Base
  set_table_name "cx_geographiclocation"
end

class MigrationMysqlTest < Test::Unit::TestCase
  
  def test_creation_modification
    #creation
    #add column
    #remove column
    #add index
    #remove index
    
    connection = ActiveRecord::Base.connection

    #create a table with a geometric column
    ActiveRecord::Schema.define() do
      create_table "parks", :options => "ENGINE=MyISAM" , :force => true do |t|
        t.column "data" , :string, :limit => 100
        t.column "value", :integer
        t.column "geom", :polygon,:null=>false
      end
    end
    
    #TEST
    assert_equal(4,connection.columns("parks").length) # the 3 defined + id
    connection.columns("parks").each do |col|
      if col.name == "geom"
        assert(col.is_a?(SpatialColumn))
        assert(:polygon,col.geometry_type)
        assert(:geometry,col.type)
        assert(col.null == false)
      end
    end

    ActiveRecord::Schema.define() do
      add_column "parks","geom2", :multi_point
    end
    
    #TEST
    assert_equal(5,connection.columns("parks").length)
    connection.columns("parks").each do |col|
      if col.name == "geom2"
        assert(col.is_a?(SpatialColumn))
        assert(:multi_point,col.geometry_type)
        assert(:geometry,col.type)
        assert(col.null != false)
      end
    end
    
    ActiveRecord::Schema.define() do
      remove_column "parks","geom2"
    end

    #TEST
    assert_equal(4,connection.columns("parks").length)
    has_geom2= false
    connection.columns("parks").each do |col|
      if col.name == "geom2"
        has_geom2=true
      end
    end
    assert(!has_geom2)
    
    #TEST
    assert_equal(0,connection.indexes("parks").length) #index on id does not count
    
    ActiveRecord::Schema.define() do      
      add_index "parks","geom",:spatial=>true
    end
    
    #TEST
    assert_equal(1,connection.indexes("parks").length)
    assert(connection.indexes("parks")[0].spatial)
   
    ActiveRecord::Schema.define() do
      remove_index "parks","geom"
    end
    
    #TEST
    assert_equal(0,connection.indexes("parks").length)
    
  end

  
  def test_dump
    #Force the creation a table
    ActiveRecord::Schema.define() do
      create_table "parks", :options => "ENGINE=MyISAM" , :force => true do |t|
        t.column "data" , :string, :limit => 100
        t.column "value", :integer
        t.column "geom", :polygon,:null=>false
      end
      
      add_index "parks","geom",:spatial=>true,:name => "example_spatial_index"
    
    end

    #dump it : tables from other tests will be dumped too but not a problem
    File.open('schema.rb', "w") do |file|
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
    end
    
    #load it again 
    load('schema.rb')
    
    File.delete('schema.rb')

    #reset
    connection = ActiveRecord::Base.connection

    columns = connection.columns("parks")
    assert(4,columns.length)
    
    connection.columns("parks").each do |col|
      if col.name == "geom"
        assert(col.is_a?(SpatialColumn))
        assert(:polygon,col.geometry_type)
        assert(:geometry,col.type)
        assert(col.null == false)
      end
    end

    assert_equal(1,connection.indexes("parks").length)
    assert(connection.indexes("parks")[0].spatial)
    assert_equal("example_spatial_index",connection.indexes("parks")[0].name)
   end

  def test_teresa
     connection = ActiveRecord::Base.connection
    
    #creation
    ActiveRecord::Schema.define() do
      create_table(:cx_geographiclocation, :primary_key => "GeographicLocationID", :options=>"ENGINE=MyISAM", :force => true ) do |t|
        t.column "CountryID", :integer,                           :null => false
        t.column  "AddressLine1", :string,         :limit => 100, :null => false
        t.column  "AddressLine2",  :string,        :limit => 100
        t.column  "AddressLine3", :string,        :limit => 50
        t.column  "City", :string,                :limit => 50
        t.column  "StateProvince", :string,       :limit => 50
        t.column  "PostalCode", :string,          :limit => 30
        t.column  "Geocode", :geometry, :null  => false #:geometry ok too : col.geometry_type test to change below
      end
    end
    
    #test creation
    assert_equal(9,connection.columns("cx_geographiclocation").length)
    connection.columns("cx_geographiclocation").each do |col|
      if col.name == "Geocode"
        assert(col.is_a?(SpatialColumn))
        assert(:geometry,col.type)
        assert(:point,col.geometry_type)
        assert(! col.null)
      end
    end

    #creation index
    ActiveRecord::Schema.define() do
      add_index "cx_geographiclocation", ["addressline1"], :name => "ix_cx_geographiclocation_addressline1"
      add_index "cx_geographiclocation", ["countryid"], :name => "ix_cx_geographiclocation_countryid"
      add_index "cx_geographiclocation", ["Geocode"], :spatial=>true
    end

    #test index
    assert_equal(3,connection.indexes("cx_geographiclocation").length)
    assert(connection.indexes("cx_geographiclocation")[2].spatial)    

    #insertion points
    1.upto(10000) do |i|
      pt = CxGeographiclocation.new("CountryID" => i, "AddressLine1" =>"Bouyoul", "Geocode" => Point.from_x_y(-180 + rand(360) + rand(),-90 + rand(180) + rand())) #insert floats
      assert(pt.save)
    end
    
    #should be outside the fetch by MBR
    pt = CxGeographiclocation.new("CountryID" => 1337, "AddressLine1" =>"Bouyoul", "Geocode" => Point.from_x_y(-185,-90)) #insert floats
    assert(pt.save)
    
    #fetch point and test
    pt = CxGeographiclocation.find(:first)
    assert(pt)
    assert_equal("Bouyoul",pt.attributes["AddressLine1"])


    #fetch by MBR and test
    pts =  CxGeographiclocation.find_all_by_Geocode([[-181 + rand(),-91 + rand()],[181 + rand(),91 + rand()]]) #selects all : range limits are float
    assert(pts)
    assert(pts.is_a?(Array))
    assert_equal(10000,pts.length)
    assert_equal("Bouyoul",pts[0].attributes["AddressLine1"])

   end

  

  
end
