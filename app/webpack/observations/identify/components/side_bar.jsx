import React from "react";
import PropTypes from "prop-types";
import ProgressChartContainer from "../containers/progress_chart_container";

const SideBar = ( { blind, hidden, setSideBarHidden } ) => (
  <div className="SideBar">
    <button
      className="hide-button"
      type="button"
      onClick={() => setSideBarHidden( !hidden )}
    >
      <i className={`fa fa-angle-double-${hidden ? "left" : "right"}`} />
    </button>
    { hidden ? null : <ProgressChartContainer /> }
    { blind ? (
      <div className="alert alert-warning">
        <p>
          <strong>
            How accurate are crowd-sourced taxonomic identifications by citizen scientists?
          </strong>
        </p>
        <p>
          Thanks for volunteering your taxonomic expertise to evaluate
          iNaturalist data quality. This is a "blind" version of the iNaturalist
          "Identify" tool that hides the opinions of the iNaturalist community.
          Please be aware that your identifications will be shared with the
          observers and the broader
          community. <a href="/pages/identification_quality_experiment" target="_blank">
            Click here
          </a> to learn more about the study.
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
            than you can, please check "Others could potentially refine this ID"
            before saving your ID.
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
  blind: PropTypes.bool,
  hidden: PropTypes.bool,
  setSideBarHidden: PropTypes.func
};

export default SideBar;
