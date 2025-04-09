import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Col } from "react-bootstrap";
import QualityGradePieChart from "./quality_grade_pie_chart";

import HeaderWithMoreLink from "./header_with_more_link";

const OverviewStats = ( { project, setSelectedTab } ) => {
  if ( !project.quality_grade_counts_loaded ) {
    return ( <div className="loading_spinner" /> );
  }
  if ( _.isEmpty( project.quality_grade_counts.results ) ) { return ( <div /> ); }
  return (
    <Col xs={4}>
      <HeaderWithMoreLink onClick={( ) => setSelectedTab( "stats" )}>
        { I18n.t( "stats" ) }
      </HeaderWithMoreLink>
      <QualityGradePieChart project={project} />
    </Col>
  );
};

OverviewStats.propTypes = {
  project: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default OverviewStats;
