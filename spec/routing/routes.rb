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
end
