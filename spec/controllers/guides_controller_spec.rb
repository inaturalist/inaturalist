require File.dirname(__FILE__) + '/../spec_helper'

describe GuidesController, "show" do
  describe "published guide" do
    let(:g) { make_published_guide }
    it "should be visible to signed out visitors" do
      get :show, id: g.id
      expect(response).to be_success
    end
  end
  describe "draft guide" do
    let(:g) { Guide.make! }
    before do
      expect(g).not_to be_published
    end
    it "should not be viewable by signed out visitors" do
      get :show, id: g.id
      expect(response).to be_not_found
    end
    it "should not be viewable by any signed in visitor" do
      sign_in User.make!
      get :show, id: g.id
      expect(response).to be_not_found
    end
    it "should be viewable by guide editor if the guide is a draft" do
      gu = GuideUser.make!(guide: g)
      sign_in gu.user
      get :show, id: g.id
      expect(response).to be_success
    end
  end
end

describe GuidesController, "index" do
  it "should filter by place" do
    p1 = make_place_with_geom
    p2 = make_place_with_geom
    g = make_published_guide(place: p1)
    get :index, :place_id => p1.id
    expect(assigns(:guides)).to include g
    get :index, :place_id => p2.id
    expect(assigns(:guides)).not_to include g
  end
end

describe GuidesController, "update" do
  let(:user) { User.make! }
  let(:guide) { make_published_guide(user: user) }
  before do
    sign_in user
  end
  it "should publish the guide based on the publish param" do
    guide.update_attribute(:published_at, nil)
    expect(guide).not_to be_published
    patch :update, id: guide.id, publish: true
    guide.reload
    expect(guide).to be_published
  end
  it "should unpublish the guide" do
    expect(guide).to be_published
    patch :update, id: guide.id, unpublish: true
    guide.reload
    expect(guide).not_to be_published
  end
  it "should change the title" do
    patch :update, id: guide.id, guide: {title: "this is a new title"}
    guide.reload
    expect(guide.title).to eq "this is a new title"
  end
  it "should allow assignment of nested guide users" do
    u = User.make!
    patch :update, id: guide.id, guide: {guide_users_attributes: {"0": {user_id: u.id}}} 
    guide.reload
    expect(guide.guide_users.size).to eq 2
  end
end

describe GuidesController, "import_taxa" do
  describe "from names" do
    before do
      @guide = Guide.make!
      sign_in @guide.user
    end
    it "should add guide taxa" do
      taxa = 3.times.map{Taxon.make!}
      expect(@guide.guide_taxa).to be_blank
      post :import_taxa, id: @guide, names: taxa.map(&:name).join("\n"), format: :json
      @guide.reload
      expect(@guide.guide_taxa.count).to eq 3
    end
  end
end

describe GuidesController, "import_tags_from_csv" do
  let(:guide) { make_published_guide }
  let(:taxon_names) { guide.guide_taxa.sort_by(&:name).map(&:name) }
  let(:work_path) { File.join(Dir::tmpdir, "import_tags_from_csv-#{Time.now.to_i}.csv") }
  before do
    sign_in guide.user
  end
  
  it "should add plain tags when no predicate listed" do
    CSV.open(work_path, 'w') do |csv|
      csv << ['name']
      csv << [taxon_names[0], 'shifty']
      csv << [taxon_names[1], 'forthright']
      csv << [taxon_names[2], '']
      csv
    end
    put :import_tags_from_csv, id: guide.id, file: work_path
    guide_taxa = guide.guide_taxa(reload: true).sort_by(&:name)
    expect( guide_taxa[0].tag_list ).to include 'shifty'
    expect( guide_taxa[1].tag_list ).to include 'forthright'
  end
  
  it "should add tags with predicates" do
    CSV.open(work_path, 'w') do |csv|
      csv << ['name',         'color', 'size']
      csv << [taxon_names[0], 'red',   'big']
      csv << [taxon_names[1], 'green', 'small']
      csv << [taxon_names[2], 'blue',  'small']
      csv
    end
    put :import_tags_from_csv, id: guide.id, file: work_path
    guide_taxa = guide.guide_taxa(reload: true).sort_by(&:name)
    expect( guide_taxa.first.tag_list ).to include 'color=red'
    expect( guide_taxa.last.tag_list ).to include 'color=blue'
    expect( guide_taxa.first.tag_list ).to include 'size=big'
  end

  it "should add tags with namespaces and predicates" do
    CSV.open(work_path, 'w') do |csv|
      csv << ['name',         'taxonomy:family']
      csv << [taxon_names[0], 'Ranidae']
      csv << [taxon_names[1], 'Lycaenidae']
      csv << [taxon_names[2], 'Pompilidae']
      csv
    end
    put :import_tags_from_csv, id: guide.id, file: work_path
    guide_taxa = guide.guide_taxa(reload: true).sort_by(&:name)
    expect( guide_taxa[0].tag_list ).to include 'taxonomy:family=Ranidae'
    expect( guide_taxa[1].tag_list ).to include 'taxonomy:family=Lycaenidae'
    expect( guide_taxa[2].tag_list ).to include 'taxonomy:family=Pompilidae'
  end

  it "should add multiple tags per cell separated by pipes" do
    CSV.open(work_path, 'w') do |csv|
      csv << ['name',         'color']
      csv << [taxon_names[0], 'red|green',   'big']
      csv << [taxon_names[1], 'green', 'small']
      csv << [taxon_names[2], 'blue',  'small|medium']
      csv
    end
    put :import_tags_from_csv, id: guide.id, file: work_path
    guide_taxa = guide.guide_taxa(reload: true).sort_by(&:name)
    expect( guide_taxa.first.tag_list ).to include 'color=red'
    expect( guide_taxa.first.tag_list ).to include 'color=green'
    expect( guide_taxa.last.tag_list ).to include 'small'
    expect( guide_taxa.last.tag_list ).to include 'medium'
  end

  it "should not add tags for blanks" do
    CSV.open(work_path, 'w') do |csv|
      csv << ['name',         'color']
      csv << [taxon_names[0], '']
      csv << [taxon_names[1], 'green']
      csv << [taxon_names[2], 'blue']
      csv
    end
    put :import_tags_from_csv, id: guide.id, file: work_path
    guide_taxa = guide.guide_taxa(reload: true).sort_by(&:name)
    expect( guide_taxa.first.tag_list ).to be_blank
    expect( guide_taxa.last.tag_list ).to include 'color=blue'
  end

  it "should leave existing tags intact" do
    gt = guide.guide_taxa.sort_by(&:name).first
    gt.update_attributes(tag_list: %w(foo bar))
    CSV.open(work_path, 'w') do |csv|
      csv << ['name']
      csv << [taxon_names[0], 'shifty']
      csv << [taxon_names[1], 'forthright']
      csv << [taxon_names[2], '']
      csv
    end
    put :import_tags_from_csv, id: guide.id, file: work_path
    guide_taxa = guide.guide_taxa(reload: true).sort_by(&:name)
    gt.reload
    expect( gt.tag_list ).to include 'shifty'
    expect( gt.tag_list ).to include 'foo'
    expect( gt.tag_list ).to include 'bar'
  end

  it "should fail gracefully without a file" do
    put :import_tags_from_csv, id: guide.id
    expect( response ).not_to be_server_error
  end
end

describe GuidesController, "import_tags_from_csv_template" do
  let(:guide) { make_published_guide }
  before do
    sign_in guide.user
  end
  it "should include columns for predicates of all tags in the guide" do
    guide.guide_taxa.each do |gt|
      gt.update_attributes(tag_list: "size=small,color=red")
    end
    get :import_tags_from_csv_template, format: :csv, id: guide.id
    csv = CSV.parse(response.body, headers: true)
    expect( csv.headers ).to include 'size'
    expect( csv.headers ).to include 'color'
  end
  it "should include rows for all taxa in the guide" do
    get :import_tags_from_csv_template, format: :csv, id: guide.id
    names = []
    CSV.parse(response.body, headers: true).each do |row|
      names << row[0]
    end
    guide.guide_taxa.each do |gt|
      expect( names ).to include gt.name
    end
  end
end
