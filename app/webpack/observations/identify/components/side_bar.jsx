import React from "react";
import ProgressChartContainer from "../containers/progress_chart_container";
import BulkActions from "./bulk_actions";
import IdentifierStats from "./identifier_stats";

const SideBar = () => (
  <div className="SideBar">
    <ProgressChartContainer />
    <BulkActions />
    <IdentifierStats />
  </div>
);

export default SideBar;
