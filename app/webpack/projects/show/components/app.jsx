import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import IdentifiersTabContainer from "../containers/identifiers_tab_container";
import ObservationsTabContainer from "../containers/observations_tab_container";
import ObserversTabContainer from "../containers/observers_tab_container";
import OverviewTabContainer from "../containers/overview_tab_container";
import SpeciesTabContainer from "../containers/species_tab_container";
import StatsHeaderContainer from "../containers/stats_header_container";

const App = ( { config, project } ) => {
  let view;
  switch ( config.selectedTab ) {
    case "observations":
      view = ( <ObservationsTabContainer /> );
      break;
    case "identifiers":
      view = ( <IdentifiersTabContainer /> );
      break;
    case "observers":
      view = ( <ObserversTabContainer /> );
      break;
    case "species":
      view = ( <SpeciesTabContainer /> );
      break;
    default:
      view = ( <OverviewTabContainer /> );
  }
  return (
    <div id="ProjectsShow">
      <div className="project-header">
        <div
          className="project-header-background"
          style={ project.header_image_url ? {
            backgroundImage: `url( '${project.header_image_url}' )`
          } : null }
        />
        <Grid className="header-grid">
          <Row>
            <Col
              xs={ 8 }
              className="title-container"
              style={ project.header_image_url ? {
                backgroundImage: `url( '${project.header_image_url}' )`
              } : null }
            >
              <div className="header-title">
                { project.icon && (
                  <div
                    className="title-icon"
                    style={ { backgroundImage: `url( '${project.icon}' )` } }
                  />
                ) }
                <div className="title-text">
                  { project.title }
                </div>
              </div>
            </Col>
            <Col xs={ 4 } className="header-about">
              <div>
                <div className="header-about-title">
                  { I18n.t( "about" ) }
                </div>
                <div className="header-about-follow">
                  <button>{ I18n.t( "follow" ) }</button>
                </div>
              </div>
              <div className="header-about-text">
                { project.description.substring( 0, 240 ) }...
              </div>
              <div className="header-about-read-more">
                { I18n.t( "read_more" ) }
                <i className="fa fa-chevron-right" />
              </div>
              <div className="header-about-news">
                <i className="fa fa-bell" />
                { I18n.t( "news" ) }
              </div>
            </Col>
          </Row>
        </Grid>
      </div>
      <StatsHeaderContainer />
      <div className="Content">
        { view }
      </div>
    </div>
  );
};

App.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object
};

export default App;
