require File.expand_path("../../spec_helper", __FILE__)

describe 'WillPaginate::ActiveRecord::Pagination' do

  before do
    5.times{ Observation.make! }
    @opts = { page: 1, per_page: 2 }
    @original = Observation.paginate(@opts)
    @with_count = Observation.paginate_with_count_over(@opts)
  end

  it "paginate_with_count_over should return data the same as paginate" do
    expect(@original.class).to be @with_count.class
    expect(@original.total_entries).to be @with_count.total_entries
    expect(@original.first).to eq @with_count.first
  end

  it "paginate_with_count_over should use a COUNT() OVER() query" do
    expect(@original.to_sql).to_not match(/COUNT\(.*?\) OVER\(\)/)
    expect(@with_count.to_sql).to match(/COUNT\(.*?\) OVER\(\)/)
  end

  it "to_a should have the same total_entries as paginate" do
    expect(@with_count.to_a.total_entries).to be @original.to_a.total_entries
  end

end
