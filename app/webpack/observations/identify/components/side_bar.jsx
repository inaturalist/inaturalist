import React from "react";
import ProgressChart from "./progress_chart";
import BulkActions from "./bulk_actions";
import IdentifierStats from "./identifier_stats";

const SideBar = () => (
  <div className="SideBar">
    <ProgressChart />
    <BulkActions />
    <IdentifierStats />
  </div>
);

export default SideBar;
