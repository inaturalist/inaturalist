# frozen_string_literal: true

require "spec_helper"

describe BlogCategory do
  it { is_expected.to belong_to :site }
  it { is_expected.to have_many( :posts ).dependent( :restrict_with_error ) }
  it { is_expected.to validate_presence_of :label }
  it { is_expected.to validate_presence_of :slug }

  it "requires a unique slug per site" do
    existing = BlogCategory.make!
    expect( BlogCategory.make( site: existing.site, slug: existing.slug ) ).not_to be_valid
    expect( BlogCategory.make( slug: existing.slug ) ).to be_valid
  end

  it "only allows lowercase letters, digits and hyphens in the slug" do
    expect( BlogCategory.make( slug: "behind-the-observation-2" ) ).to be_valid
    expect( BlogCategory.make( slug: "Behind the Observation" ) ).not_to be_valid
  end

  it "reserves the all slug" do
    expect( BlogCategory.make( slug: "all" ) ).not_to be_valid
  end

  it "cannot be destroyed while it has posts" do
    category = BlogCategory.make!
    Post.make!( parent: category.site, blog_category: category )
    expect( category.destroy ).to be false
    expect( BlogCategory.exists?( category.id ) ).to be true
  end
end
