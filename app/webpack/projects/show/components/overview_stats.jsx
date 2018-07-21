import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Col } from "react-bootstrap";
import IconicTaxaPieChart from "./iconic_taxa_pie_chart";

class OverviewStats extends Component {
  render( ) {
    const { project, setSelectedTab } = this.props;
    if ( !project.iconic_taxa_species_counts_loaded ) {
      return ( <div className="loading_spinner" /> );
    }
    if ( _.isEmpty( project.iconic_taxa_species_counts.results ) ) { return ( <div /> ); }
    return (
      <Col xs={ 4 }>
        <h2>
          { I18n.t( "stats" ) }
          <i
            className="fa fa-arrow-circle-right"
            onClick={ ( ) => setSelectedTab( "stats" ) }
          />
        </h2>
        <IconicTaxaPieChart { ...this.props } />
      </Col>
    );
  }
}

OverviewStats.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default OverviewStats;
