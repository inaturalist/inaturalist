require File.dirname(__FILE__) + '/../spec_helper.rb'

def setup_taxon_merge
  @input_taxon1 = Taxon.make!
  @input_taxon2 = Taxon.make!
  @output_taxon = Taxon.make!
  @merge = TaxonMerge.make
  @merge.add_input_taxon(@input_taxon1)
  @merge.add_input_taxon(@input_taxon2)
  @merge.add_output_taxon(@output_taxon)
  @merge.save!
end

describe TaxonMerge, "commit" do
  before(:each) do
    setup_taxon_merge
  end

  it "should not duplicate conservation status" do
    @input_taxon1.update_attribute(:conservation_status, Taxon::IUCN_ENDANGERED)
    expect(@output_taxon.conservation_status).to be_blank
    @merge.commit
    expect(@output_taxon.conservation_status).to be_blank
  end

  it "should duplicate taxon names" do
    name1 = "Tyra"
    name2 = "Landry"
    TaxonName.make!(:name => name1, :lexicon => TaxonName::ENGLISH, :taxon => @input_taxon1)
    TaxonName.make!(:name => name2, :lexicon => TaxonName::ENGLISH, :taxon => @input_taxon2)
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_names.detect{|tn| tn.name == name1}).not_to be_blank
    expect(@output_taxon.taxon_names.detect{|tn| tn.name == name2}).not_to be_blank
  end

  it "should mark the duplicate of the input taxon's sciname as invalid" do
    @merge.commit
    @output_taxon.reload
    tn1 = @output_taxon.taxon_names.detect{|tn| tn.name == @input_taxon1.name}
    tn2 = @output_taxon.taxon_names.detect{|tn| tn.name == @input_taxon2.name}
    expect(tn1).not_to be_blank
    expect(tn1).not_to be_is_valid
    expect(tn2).not_to be_blank
    expect(tn2).not_to be_is_valid
  end

  it "should not duplicate taxon range if one is already set" do
    tr1 = TaxonRange.make!(:taxon => @input_taxon1)
    tr2 = TaxonRange.make!(:taxon => @output_taxon)
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_ranges.count).to eq(1)
  end

  it "should duplicate colors" do
    color = Color.create(:value => "red")
    @input_taxon1.colors << color
    @input_taxon2.colors << color
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon.colors.count).to eq(1)
  end

  it "should not duplicate conservation_statuses" do
    cs1 = ConservationStatus.make!(:taxon => @input_taxon1, :authority => "foo")
    cs2 = ConservationStatus.make!(:taxon => @input_taxon2, :authority => "bar")
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon.conservation_statuses).to be_blank
  end

  it "should generate updates for observers of the old taxon"
  it "should generate updates for identifiers of the old taxon"
  it "should generate updates for listers of the old taxon"

  it "should mark the input taxon as inactive" do
    @merge.commit
    @input_taxon1.reload
    expect(@input_taxon1).not_to be_is_active
    @input_taxon2.reload
    expect(@input_taxon2).not_to be_is_active
  end

  it "should mark the output taxon as active" do
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon).to be_is_active
  end
end

describe TaxonMerge, "commit_records" do
  before(:each) do
    setup_taxon_merge
  end
  it "should add new identifications" do
    ident = Identification.make!( taxon: @input_taxon1 )
    @merge.commit_records
    ident.reload
    expect(ident).not_to be_current
    new_ident = ident.observation.identifications.by(ident.user).order("id asc").last
    expect(new_ident).not_to eq(ident)
    expect(new_ident.taxon).to eq(@output_taxon)
  end

  it "should not add multiple identifications" do
    ident = Identification.make!( taxon: @input_taxon1, observation: Observation.make!(taxon: @input_taxon1) )
    2.times do
      Identification.make!( taxon: @input_taxon1, observation: ident.observation )
    end
    expect( ident.observation.identifications.by( ident.observation.user ).count ).to eq 1
    @merge.commit_records
    ident.reload
    expect( ident.observation.identifications.by( ident.observation.user ).count ).to eq 2
  end
  it "should not add multiple identifications for the observer when run twice and the obs is still associated with the old taxon" do
    o = make_research_grade_observation( taxon: @input_taxon1 )
    expect( o.identifications.by( o.user ).count ).to eq 1
    @merge.commit_records
    5.times do
      Identification.make!( observation: o, taxon: @input_taxon1 )
    end
    o.reload
    expect( o.taxon ).to eq @input_taxon1
    @merge.commit_records
    o.reload
    expect( o.identifications.by( o.user ).count ).to eq 2
  end
end
