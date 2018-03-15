import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import { numberWithCommas } from "../../../shared/util";

const StatsHeader = ( { config, project, setSelectedTab } ) => {
  return (
    <div className="StatsHeader">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <ul>
              <li
                className={ `overview-tab ${config.selectedTab === "overview" && "active"}` }
                onClick={ ( ) => setSelectedTab( project.is_umbrella ? "umbrella_overview" : "overview" ) }
              >
                { I18n.t( "overview" ) }
              </li>
              <li
                className={ `stat-tab ${config.selectedTab === "observations" && "active"}` }
                onClick={ ( ) => setSelectedTab( "observations" ) }
              >
                <span className="stat">
                  { project.observations_loaded ? numberWithCommas( project.observations.total_results ) : "--" }
                </span>
                { I18n.t( "observations" ) }
              </li>
              <li
                className={ `stat-tab ${config.selectedTab === "species" && "active"}` }
                onClick={ ( ) => setSelectedTab( "species" ) }
              >
                <span className="stat">
                  { project.species_loaded ? numberWithCommas( project.species.total_results ) : "--" }
                </span>
                { I18n.t( "species" ) }
              </li>
              <li
                className={ `stat-tab ${config.selectedTab === "identifiers" && "active"}` }
                onClick={ ( ) => setSelectedTab( "identifiers" ) }
              >
                <span className="stat">
                  { project.identifiers_loaded ? numberWithCommas( project.identifiers.total_results ) : "--" }
                </span>
                { I18n.t( "identifiers" ) }
              </li>
              <li
                className={ `stat-tab ${config.selectedTab === "observers" && "active"}` }
                onClick={ ( ) => setSelectedTab( "observers" ) }
              >
                <span className="stat">
                  { project.observers_loaded ? numberWithCommas( project.observers.total_results ) : "--" }
                </span>
                { I18n.t( "observers" ) }
              </li>
              <li className="stats-tab">
                <button className="btn-white">
                  <i className="fa fa-bolt" />
                  { I18n.t( "stats" ) }
                </button>
              </li>
            </ul>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

StatsHeader.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default StatsHeader;
