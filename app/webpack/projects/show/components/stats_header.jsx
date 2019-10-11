import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import { numberWithCommas } from "../../../shared/util";

const StatsHeader = ( { config, project, setSelectedTab } ) => {
  const tab = config.selectedTab || "overview";
  const obsCount = project.recent_observations_loaded ?
    numberWithCommas( project.recent_observations.total_results ) : "--";
  const speciesCount = project.species_loaded ?
    numberWithCommas( project.species.total_results ) : "--";
  const identifiersCount = project.identifiers_loaded ?
    numberWithCommas( project.identifiers.total_results ) : "--";
  const observersCount = project.observers_loaded ?
    numberWithCommas( project.observers.total_results ) : "--";
  const obsDisabled = ( obsCount === "0" || obsCount === "--" ) ? "disabled" : null;
  const speciesDisabled = ( speciesCount === "0" || speciesCount === "--" ) ? "disabled" : null;
  const identifiersDisabled = ( identifiersCount === "0" || identifiersCount === "--" ) ? "disabled" : null;
  const observersDisabled = ( observersCount === "0" || observersCount === "--" ) ? "disabled" : null;
  const statsDisabled = observersCount === "0" ? "disabled" : null;
  return (
    <div className="StatsHeader">
      <Grid>
        <Row>
          <Col xs={12}>
            <ul>
              <li
                className={`overview-tab ${tab === "overview" && "active"}`}
                onClick={( ) =>
                  setSelectedTab( project.is_umbrella ? "umbrella_overview" : "overview" )
                }
              >
                { I18n.t( "overview" ) }
              </li>
              <li
                className={`stat-tab ${tab === "observations" && "active"} ${obsDisabled}`}
                onClick={( ) => setSelectedTab( "observations" )}
                dangerouslySetInnerHTML={{ __html: I18n.t( "x_observations_html", { count: obsCount } ) }}
              />
              <li
                className={`stat-tab ${tab === "species" && "active"} ${speciesDisabled}`}
                onClick={( ) => setSelectedTab( "species" )}
                dangerouslySetInnerHTML={{ __html: I18n.t( "x_species_html", { count: speciesCount } ) }}
              />
              <li
                className={`stat-tab ${tab === "identifiers" && "active"} ${identifiersDisabled}`}
                onClick={( ) => setSelectedTab( "identifiers" )}
                dangerouslySetInnerHTML={{ __html: I18n.t( "x_identifiers_html", { count: identifiersCount } ) }}
              />
              <li
                className={`stat-tab ${tab === "observers" && "active"} ${observersDisabled}`}
                onClick={( ) => setSelectedTab( "observers" )}
                dangerouslySetInnerHTML={{ __html: I18n.t( "x_observers_html", { count: observersCount } ) }}
              />
              <li className="stats-tab">
                <button
                  className={ `${config.selectedTab === "stats" ? "btn-green" : "btn-white"} ${statsDisabled}` }
                  onClick={ ( ) => setSelectedTab( "stats" ) }
                >
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
