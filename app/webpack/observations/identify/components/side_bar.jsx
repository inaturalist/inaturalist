import React from "react";
import ProgressChartContainer from "../containers/progress_chart_container";
import BulkActionsContainer from "../containers/bulk_actions_container";
import IdentifierStatsContainer from "../containers/identifier_stats_container";

const SideBar = () => (
  <div className="SideBar">
    <ProgressChartContainer />
    <BulkActionsContainer />
    <IdentifierStatsContainer />
  </div>
);

export default SideBar;
