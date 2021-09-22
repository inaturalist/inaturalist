require "spec_helper.rb"

describe Site do
  it { is_expected.to have_many(:observations).inverse_of :site }
  it { is_expected.to have_many(:users).inverse_of :site }
  it { is_expected.to have_many(:site_admins).inverse_of :site }
  it { is_expected.to have_many(:posts).dependent :destroy }
  it { is_expected.to have_many(:journal_posts).class_name("Post").dependent :destroy }
  it { is_expected.to have_many(:site_featured_projects).dependent :destroy }
  it { is_expected.to have_and_belong_to_many :announcements }
  it { is_expected.to belong_to(:place).inverse_of :sites }
  it { is_expected.to belong_to(:extra_place).inverse_of(:extra_place_sites).class_name "Place" }
  it { is_expected.to belong_to(:taxon_range_source).class_name("Source").with_foreign_key "source_id" }
end
