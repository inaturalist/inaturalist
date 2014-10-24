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
    TaxonAncestor.count.should == 0
    AncestryDenormalizer.denormalize
    TaxonAncestor.count.should == 21
    TaxonAncestor.exists?(taxon_id: 1, ancestor_taxon_id: 1).should be_true
    TaxonAncestor.exists?(taxon_id: 2, ancestor_taxon_id: 2).should be_true
    TaxonAncestor.exists?(taxon_id: 2, ancestor_taxon_id: 1).should be_true
    TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 6).should be_true
    TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 5).should be_true
    TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 4).should be_true
    TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 3).should be_true
    TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 2).should be_true
    TaxonAncestor.exists?(taxon_id: 6, ancestor_taxon_id: 1).should be_true
  end

  it 'should truncate the table' do
    AncestryDenormalizer.truncate
    TaxonAncestor.count.should == 0
    AncestryDenormalizer.denormalize
    TaxonAncestor.count.should == 21
    AncestryDenormalizer.truncate
    TaxonAncestor.count.should == 0
  end

end
