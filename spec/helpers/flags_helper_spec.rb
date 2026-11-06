# frozen_string_literal: true

require "spec_helper"

describe FlagsHelper do
  # link_to_user lives in UsersHelper, which helper specs don't include by default
  include UsersHelper

  describe "flag_resolver" do
    let( :site ) { Site.default || Site.make! }

    it "links to the resolver" do
      resolver = User.make!
      flag = build :flag, resolver: resolver
      expect( flag_resolver( flag, site ) ).to have_tag( "a", text: resolver.login )
    end

    it "says the user was deleted when the resolver no longer exists" do
      flag = build :flag, resolver_id: User.maximum( :id ).to_i + 1000
      expect( flag_resolver( flag, site ) ).to eq I18n.t( :deleted_user )
    end

    it "uses the site name when the flag has no resolver" do
      flag = build :flag, resolver_id: nil
      expect( flag_resolver( flag, site ) ).to eq site.name
    end

    it "uses the site name for legacy system resolver ids" do
      flag = build :flag, resolver_id: 0
      expect( flag_resolver( flag, site ) ).to eq site.name
    end
  end
end
