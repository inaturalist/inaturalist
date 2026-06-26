# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "routes" do
  describe "/observations/:id" do
    it "should treat UUIDs like IDs" do
      expect( get: "/observations/e3b5b8bd-0df5-402c-bf57-68b2a1c81290" ).to route_to(
        controller: "observations",
        action: "show",
        id: "e3b5b8bd-0df5-402c-bf57-68b2a1c81290"
      )
    end
  end

  describe "taxon routes" do
    it "routes the default taxon URL" do
      expect( get: "/taxa/891696-Pica-pica" ).to route_to(
        controller: "taxa",
        action: "show",
        id: "891696-Pica-pica"
      )
    end

    it "routes a locale-prefixed taxon URL" do
      expect( get: "/fr/taxa/891696-Pica-pica" ).to route_to(
        controller: "taxa",
        action: "show",
        id: "891696-Pica-pica",
        locale: "fr"
      )
    end

    it "does not route an English-prefixed taxon URL" do
      expect( get: "/en/taxa/891696-Pica-pica" ).not_to be_routable
    end

    it "does not route an unknown locale taxon URL" do
      expect( get: "/xx/taxa/891696-Pica-pica" ).not_to be_routable
    end
  end
end
