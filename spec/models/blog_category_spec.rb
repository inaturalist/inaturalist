# frozen_string_literal: true

require "spec_helper"

describe BlogCategory do
  it { is_expected.to belong_to :site }
  it { is_expected.to have_many( :posts ).dependent( :restrict_with_error ) }
  it { is_expected.to validate_presence_of :label }

  it "generates the slug from the label" do
    expect( BlogCategory.make!( label: "Behind the Observation" ).slug ).to eq "behind-the-observation"
  end

  it "keeps slugs unique per site" do
    first = BlogCategory.make!( label: "Updates" )
    expect( BlogCategory.make!( site: first.site, label: "Updates" ).slug ).not_to eq first.slug
    expect( BlogCategory.make!( label: "Updates" ).slug ).to eq "updates"
  end

  it "reserves the all slug" do
    expect( BlogCategory.make( label: "All" ) ).not_to be_valid
  end

  it "still gets a slug when the label has no Latin characters" do
    expect( BlogCategory.make!( label: "観察の裏側" ).slug ).to be_present
  end

  it "updates the slug when the label changes and still finds it by the old one" do
    category = BlogCategory.make!( label: "Product Updates" )
    category.update!( label: "Product and Tech Updates" )
    expect( category.slug ).to eq "product-and-tech-updates"
    expect( BlogCategory.where( site: category.site ).friendly.find( "product-updates" ) ).to eq category
  end

  it "cannot be destroyed while it has posts" do
    category = BlogCategory.make!
    Post.make!( parent: category.site, blog_category: category )
    expect( category.destroy ).to be false
    expect( BlogCategory.exists?( category.id ) ).to be true
  end
end
