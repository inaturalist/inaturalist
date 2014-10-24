require File.expand_path("../../spec_helper", __FILE__)

describe 'Denormalizer' do

  before(:all) do
    6.times { Taxon.make! }
  end

  after(:all) do
    Taxon.connection.execute('TRUNCATE TABLE taxa RESTART IDENTITY')
  end

  it "should iterate through taxa in batches" do
    expect { |b|
      Denormalizer::each_taxon_batch_with_index(2, &b)
    }.to yield_successive_args(
      [ [ Taxon.find(1), Taxon.find(2) ], 1, 3 ],
      [ [ Taxon.find(3), Taxon.find(4) ], 2, 3 ],
      [ [ Taxon.find(5), Taxon.find(6) ], 3, 3 ]
    )
  end

end
