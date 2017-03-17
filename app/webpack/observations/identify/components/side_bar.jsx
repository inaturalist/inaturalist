import React from "react";
import ProgressChartContainer from "../containers/progress_chart_container";
import IdentifierStatsContainer from "../containers/identifier_stats_container";

const SideBar = ( { blind } ) => (
  <div className="SideBar">
    <ProgressChartContainer />
    <IdentifierStatsContainer />
    { blind ? (
      <div className="alert alert-warning">
        <p><strong>You're Identifying Blind!</strong></p>
        <p>
          Thanks for volunteering to improve our data quality.
          You're using a modified version of our Identify tool where you are
          "blind" to social details like the opinions of others, who the
          observer is, etc.
        </p>
        <p>Instructions:</p>
        <ol>
          <li>
            <strong>Stay on this page while adding IDs</strong> and don't "peek" at observation
            pages to see the social context we're hiding here.
          </li>
          <li>
            <strong>Identify as specifically as you can</strong> given the
            evidence provided here. If you cannot identify to species and you
            think no one could identify to species given the evidence, identify
            to the most specific level the evidence justifies, e.g. genus or
            family. If you think someone else could identify more specifically
            than you can, please abstain and just mark as reviewed.
          </li>
          <li>
            <strong>If there are multiple species in the photos, please just abstain
            from identifying</strong> instead of adding an ID that contains all the
            photographed taxa (e.g. adding an ID of Mammalia when there is a
            photo of a dog and cat)
          </li>
        </ol>
      </div>
    ) : null }
  </div>
);

SideBar.propTypes = {
  blind: React.PropTypes.bool
};

export default SideBar;
