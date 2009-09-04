$:.unshift(File.dirname(__FILE__))

require 'test/unit'
require 'common/common_postgis'

class Park < ActiveRecord::Base
end

class Viewpark < ActiveRecord::Base
end


class MigrationPostgisTest < Test::Unit::TestCase
  
  def test_creation_modification
    #creation
    #add column
    #remove column
    #add index
    #remove index
    
    connection = ActiveRecord::Base.connection

    #create a table with a geometric column
    ActiveRecord::Schema.define do
      create_table "parks", :force => true do |t|
        t.string "data",  :limit => 100
        t.integer "value"
        t.polygon "geom", :null=>false, :srid => 555 , :with_z => true,:with_m => true
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
        assert(555,col.srid)
        assert(col.with_z)
        assert(col.with_m)
      end
    end

    ActiveRecord::Schema.define do
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
        assert(-1,col.srid)
        assert(!col.with_z)
        assert(!col.with_m)
      end
    end
    
    ActiveRecord::Schema.define do
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
    
    ActiveRecord::Schema.define do      
      add_index "parks","geom",:spatial=>true
    end
    
    #TEST
    assert_equal(1,connection.indexes("parks").length)
    assert(connection.indexes("parks")[0].spatial)
    
    ActiveRecord::Schema.define do
      remove_index "parks", "geom"
    end
    
    #TEST
    assert_equal(0,connection.indexes("parks").length)
    
    ActiveRecord::Schema.define do
      remove_column "parks","geom2"
    end
    
    #testing with point
    ActiveRecord::Schema.define do
      add_column "parks","geom2", :point
    end
    
    ActiveRecord::Schema.define do      
      add_index "parks","geom2",:spatial=>true,:name => "example_spatial_index"
    end
    
    #TEST
    assert_equal(1,connection.indexes("parks").length)
    assert(connection.indexes("parks")[0].spatial)
    assert_equal("example_spatial_index",connection.indexes("parks")[0].name)
    

  end

  def test_keyword_column_name
    ActiveRecord::Schema.define do
      create_table "parks", :force => true do |t|
        t.string "data", :limit => 100
        t.integer "value"
        #location is a postgreSQL keyword and is surrounded by double-quotes ("") when appearing in constraint descriptions ; tests a bug corrected in version 39
        t.point "location", :null=>false,:srid => 0, :with_m => true, :with_z => true
      end
    end

    connection = ActiveRecord::Base.connection
    columns = connection.columns("parks")

    assert_equal(4,columns.length) # the 3 defined + id
    columns.each do |col|
      if col.name == "location"
        assert(col.is_a?(SpatialColumn))
        assert(:point,col.geometry_type)
        assert(:geometry,col.type)
        assert(col.null == false)
        assert(0,col.srid)
        assert(col.with_z)
        assert(col.with_m)
      end
    end
  end

  
  def test_view
    ActiveRecord::Schema.define do
      create_table "parks", :force => true do |t|
        t.column "data" , :string, :limit => 100
        t.column "value", :integer
        t.column "geom", :point,:null=>false
      end
    end

    pt = Park.new(:data => "Test", :geom => Point.from_x_y(1.2,4.5))
    assert(pt.save)

    ActiveRecord::Base.connection.execute('CREATE VIEW viewparks as SELECT * from parks')
    #if not ActiveRecord::Base.connection.execute("select * from geometry_columns where f_table_name = 'viewparks' and f_geometry_column = 'geom'") #do not add if already there
      #mark the geom column in the view as geometric
      #ActiveRecord::Base.connection.execute("insert into geometry_columns values ('','public','viewparks','geom',2,-1,'POINT')")
    #end

    pt = Viewpark.find(:first)
    assert(pt)
    assert_equal("Test",pt.data)
    assert_equal(Point.from_x_y(1.2,4.5),pt.geom)

    ActiveRecord::Base.connection.execute('DROP VIEW viewparks')

  end

  
  def test_dump
    #Force the creation of a table
    ActiveRecord::Schema.define do
      create_table "parks", :force => true do |t|
        t.string "data" , :limit => 100
        t.integer "value"
        t.multi_polygon "geom", :null=>false,:srid => 0, :with_m => true, :with_z => true
      end
      
      add_index "parks","geom",:spatial=>true,:name => "example_spatial_index"
    
    end

    #dump it : tables from other tests will be dumped too but not a problem
    File.open('schema.rb', "w") do |file|
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
    end
    
    #load it again 
    load('schema.rb')
    
    #delete the schema file
    File.delete('schema.rb')

    connection = ActiveRecord::Base.connection
    columns = connection.columns("parks")

    assert_equal(4,columns.length) # the 3 defined + id
    columns.each do |col|
      if col.name == "geom"
        assert(col.is_a?(SpatialColumn))
        assert(:multi_polygon,col.geometry_type)
        assert(:geometry,col.type)
        assert(col.null == false)
        assert(0,col.srid)
        assert(col.with_z)
        assert(col.with_m)
      end
    end

    assert_equal(1,connection.indexes("parks").length)
    assert(connection.indexes("parks")[0].spatial)
    assert_equal("example_spatial_index",connection.indexes("parks")[0].name)
   end
  
end
