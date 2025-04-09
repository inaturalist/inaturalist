import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Col } from "react-bootstrap";
import QualityGradePieChart from "./quality_grade_pie_chart";

const OverviewStats = ( { project, setSelectedTab } ) => {
  if ( !project.quality_grade_counts_loaded ) {
    return ( <div className="loading_spinner" /> );
  }
  if ( _.isEmpty( project.quality_grade_counts.results ) ) { return ( <div /> ); }
  return (
    <Col xs={4}>
      <h2>
        { I18n.t( "stats" ) }
        <button
          type="button"
          className="btn btn-nostyle"
          onClick={( ) => setSelectedTab( "stats" )}
          aria-label={I18n.t( "view_more" )}
        >
          <i className="fa fa-arrow-circle-right" />
        </button>
      </h2>
      <QualityGradePieChart project={project} />
    </Col>
  );
};

OverviewStats.propTypes = {
  project: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default OverviewStats;
