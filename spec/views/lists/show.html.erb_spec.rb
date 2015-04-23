require "spec_helper"

describe "lists/show" do
  it "includes the user name in the life list title if not there already" do
    u = User.make!
    u.life_list.update_attribute(:title, " Life List")
    assign(:list, u.life_list)
    assign(:view, "plain")
    assign(:listed_taxa, WillPaginate::Collection.new(1, 30, 0))
    assign(:grouped_listed_taxa, [ ])
    render
    expect(rendered).to match /#{ u.login }'s Life List/
  end
end
