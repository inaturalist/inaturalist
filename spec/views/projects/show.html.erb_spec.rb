require "spec_helper"

describe "projects/show" do
  describe "bioblitz date range formatting" do
    before do
      @project = Project.make!(
        project_type: Project::BIOBLITZ_TYPE,
        place: make_place_with_geom,
        start_time: Time.parse("2015-06-30 12:00:00"),
        end_time: Time.parse("2015-06-30 13:00:00"))
      expect(@project.cover).to receive(:file?).and_return(true);
      assign(:kml_assets, [ ])
      assign(:project_users, [ ])
      assign(:project, @project)
      assign(:observations_url_params, { })
    end

    it "shows the right range intraday bioblitzes" do
      render
      rendered.gsub!(/(\s+|\n)/, " ")
      expect(rendered).to have_selector(".timespan",
        text: "June 30, 2015, 9:00 AM - 10:00 AM PDT")
    end

    it "shows the right range for bioblitzes ending the day after starting" do
      @project.update_column(:end_time, @project.start_time + 25.hours)
      render
      rendered.gsub!(/(\s+|\n)/, " ")
      expect(rendered).to have_selector(".timespan",
        text: "June 30, 2015, 9:00 AM - July 01, 2015, 10:00 AM PDT")
    end

    it "shows the right range for bioblitzes ending the day after starting" do
      @project.update_column(:end_time, @project.start_time + 2.days)
      render
      rendered.gsub!(/(\s+|\n)/, " ")
      expect(rendered).to have_selector(".timespan",
        text: "June 30, 2015 to July 2, 2015")
    end
  end
end
