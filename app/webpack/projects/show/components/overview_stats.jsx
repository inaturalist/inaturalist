import _ from "lodash";
import React, { Component, PropTypes } from "react";
import { Col } from "react-bootstrap";
import IconicTaxaPieChart from "./iconic_taxa_pie_chart";

class OverviewStats extends Component {
  render( ) {
    const { project } = this.props;
    if ( !project.iconic_taxa_species_counts_loaded ) {
      return ( <div className="loading_spinner" /> );
    }
    if ( _.isEmpty( project.iconic_taxa_species_counts.results ) ) { return ( <div /> ); }
    return (
      <Col xs={ 4 }>
        <h2>
          Stats
          <i className="fa fa-arrow-circle-right" />
        </h2>
        <IconicTaxaPieChart { ...this.props } />
      </Col>
    );
  }
}

OverviewStats.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object
};

export default OverviewStats;
