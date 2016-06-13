import React from "react";
import ProgressChartContainer from "../containers/progress_chart_container";
import IdentifierStatsContainer from "../containers/identifier_stats_container";

const SideBar = () => (
  <div className="SideBar">
    <ProgressChartContainer />
    <IdentifierStatsContainer />
  </div>
);

export default SideBar;
