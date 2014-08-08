require File.expand_path("../../spec_helper", __FILE__)

describe 'WillPaginate::ActiveRecord::Pagination' do

  before do
    5.times{ Observation.make! }
    @opts = { page: 1, per_page: 2 }
    @original = Observation.paginate(@opts)
    @with_count = Observation.paginate_with_count_over(@opts)
  end

  it "paginate_with_count_over should return data the same as paginate" do
    @original.class.should == @with_count.class
    @original.total_entries.should == @with_count.total_entries
    @original.first.should == @with_count.first
  end

  it "paginate_with_count_over should use a COUNT() OVER() query" do
    @original.build_arel.to_sql.should_not match(/COUNT\(.*?\) OVER\(\)/)
    @with_count.build_arel.to_sql.should match(/COUNT\(.*?\) OVER\(\)/)
  end

end
