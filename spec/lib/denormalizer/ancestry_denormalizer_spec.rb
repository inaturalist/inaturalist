require File.expand_path("../../../spec_helper", __FILE__)

describe 'AncestryDenormalizer' do

  before(:all) do
    Taxon.connection.execute('TRUNCATE TABLE taxa RESTART IDENTITY')
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
  end

  after(:all) do
    Taxon.connection.execute('TRUNCATE TABLE taxa RESTART IDENTITY')
  end

  it 'should denormalize properly' do
    AncestryDenormalizer.truncate
    expect(TaxonAncestor.count).to be 0
    AncestryDenormalizer.denormalize
    expect(TaxonAncestor.count).to be 21
    expect(TaxonAncestor.exists?(taxon_id: 1, ancestor_taxon_id: 1)).to be true
    expect(TaxonAncestor.exists?(taxon_id: 2, ancestor_taxon_id: 2)).to be true
    expect(TaxonAncestor.exists?(taxon_id: 2, ancestor_taxon_id: 1)).to be true
    expect(TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 6)).to be true
    expect(TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 5)).to be true
    expect(TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 4)).to be true
    expect(TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 3)).to be true
    expect(TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 2)).to be true
    expect(TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 1)).to be true
  end

  it 'should truncate the table' do
    AncestryDenormalizer.truncate
    expect(TaxonAncestor.count).to eq 0
    AncestryDenormalizer.denormalize
    expect(TaxonAncestor.count).to eq 21
    AncestryDenormalizer.truncate
    expect(TaxonAncestor.count).to eq 0
  end

end
