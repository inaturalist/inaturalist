import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import convert from "color-convert";
import tinycolor from "tinycolor2";
import IdentifiersTabContainer from "../containers/identifiers_tab_container";
import ObservationsTabContainer from "../containers/observations_tab_container";
import ObserversTabContainer from "../containers/observers_tab_container";
import UmbrellaOverviewTabContainer from "../containers/umbrella_overview_tab_container";
import OverviewTabContainer from "../containers/overview_tab_container";
import SpeciesTabContainer from "../containers/species_tab_container";
import StatsHeaderContainer from "../containers/stats_header_container";

const App = ( { config, project } ) => {
  let view;
  let tab = config.selectedTab;
  if ( _.isEmpty( tab ) && project.project_type === "umbrella" ) {
    tab = "umbrella_overview";
  }
  switch ( tab ) {
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
    case "umbrella_overview":
      view = ( <UmbrellaOverviewTabContainer /> );
      break;
    default:
      view = ( <OverviewTabContainer /> );
  }
  const userIsManager = config.currentUser &&
    _.includes( project.manager_ids, config.currentUser.id );
  const colorRGB = tinycolor( project.banner_color || "#28387d" ).toRgb( );
  const headerButton = userIsManager ? (
    <a href={ `/projects/${project.slug}/edit` }>
      <button>{ I18n.t( "edit" ) }</button>
    </a> ) : (
    <button>{ I18n.t( "follow" ) }</button>
  );
  const headerTitle = project.hide_title ? null : (
    <div className="header-title">
      { project.customIcon && project.customIcon( ) && (
        <div
          className="title-icon"
          style={ { backgroundImage: `url( '${project.icon}' )` } }
        />
      ) }
      <div className="title-text">
        { project.title }
      </div>
    </div>
  );
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
              } : {
                background: `rgba(${colorRGB.r},${colorRGB.g},${colorRGB.b},0.2)`
              } }
            >
              { headerTitle }
            </Col>
            <Col
              xs={ 4 }
              className="header-about"
              style={ {
                background: `rgba(${colorRGB.r},${colorRGB.g},${colorRGB.b},1)`
              } }
            >
              <div>
                <div className="header-about-title">
                  { I18n.t( "about" ) }
                </div>
                <div className="header-about-button">
                  { headerButton }
                </div>
              </div>
              <div className="header-about-text">
                { ( project.description || "" ).substring( 0, 240 ) }...
              </div>
              <div className="header-about-read-more">
                { I18n.t( "read_more" ) }
                <i className="fa fa-chevron-right" />
              </div>
              <div className="header-about-news">
                <a href={ `/projects/${project.slug}/journal` }>
                  <i className="fa fa-bell" />
                  { I18n.t( "news" ) }
                </a>
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
