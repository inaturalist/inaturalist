require File.expand_path("../../../spec_helper", __FILE__)

describe 'WindshaftDenormalizer' do

  before(:all) do
    DatabaseCleaner.clean
    last_taxon = nil
    # make six taxa, each the descendant of the previous taxon
    6.times do
      options = { }
      if last_taxon
        last_ancestry = "#{ last_taxon.ancestry }/#{ last_taxon.id }".gsub(/^\//, '')
        options = { parent_id: last_taxon.id, ancestry: last_ancestry }
      end
      last_taxon = Taxon.make!(options)
    end
    AncestryDenormalizer.denormalize
    @observation = Observation.make!(latitude: 51.18, longitude: -1.83, taxon: Taxon.last)
    @psql = ActiveRecord::Base.connection
  end

  after(:all) do
    Taxon.connection.execute('TRUNCATE TABLE taxa RESTART IDENTITY')
  end

  it 'should have 7 zoom levels' do
    WindshaftDenormalizer.zooms.count.should == 7
  end

  it 'should create_all_tables' do
    WindshaftDenormalizer.destroy_all_tables
    WindshaftDenormalizer.zooms.each do |zoom|
      @psql.table_exists?(zoom[:table]).should be_false
    end
    WindshaftDenormalizer.create_all_tables
    WindshaftDenormalizer.zooms.each do |zoom|
      @psql.table_exists?(zoom[:table]).should be_true
    end
  end

  it 'should destroy_all_tables' do
    WindshaftDenormalizer.create_all_tables
    WindshaftDenormalizer.zooms.each do |zoom|
      @psql.table_exists?(zoom[:table]).should be_true
    end
    WindshaftDenormalizer.destroy_all_tables
    WindshaftDenormalizer.zooms.each do |zoom|
      @psql.table_exists?(zoom[:table]).should be_false
    end
  end

  it 'should generate a proper SnapToGrid statement' do
    WindshaftDenormalizer.snap_for_seed(4).should ==
      "ST_SnapToGrid(geom, 0+(4/2), 75+(4/2), 4, 4)"
  end

  it 'should denormalize properly' do
    WindshaftDenormalizer.destroy_all_tables
    WindshaftDenormalizer.denormalize
    # there will be 7 entries in each table - one for each taxon representing
    # the summary for their respective branches - and one for NULL representing
    # the summary for ALL taxa
    WindshaftDenormalizer.zooms.each do |zoom|
      @psql.execute("SELECT COUNT(*) from #{ zoom[:table] }").
        first['count'].to_i.should == 7
    end
  end

end
