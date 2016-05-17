import React from "react";
import ProgressChartContainer from "../containers/progress_chart_container";
import BulkActionsContainer from "../containers/bulk_actions_container";
import IdentifierStats from "./identifier_stats";

const SideBar = () => (
  <div className="SideBar">
    <ProgressChartContainer />
    <BulkActionsContainer />
    <IdentifierStats />
  </div>
);

export default SideBar;
