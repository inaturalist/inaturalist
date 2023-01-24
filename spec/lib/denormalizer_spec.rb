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
      [ [ Taxon.first, Taxon.offset(1).first ], 1, 3 ],
      [ [ Taxon.offset(2).first, Taxon.offset(3).first ], 2, 3 ],
      [ [ Taxon.offset(4).first, Taxon.offset(5).first ], 3, 3 ]
    )
  end

end
