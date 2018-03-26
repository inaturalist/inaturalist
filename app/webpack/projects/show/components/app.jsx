import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import tinycolor from "tinycolor2";
import IdentifiersTabContainer from "../containers/identifiers_tab_container";
import ObservationsTabContainer from "../containers/observations_tab_container";
import ObserversTabContainer from "../containers/observers_tab_container";
import UmbrellaOverviewTabContainer from "../containers/umbrella_overview_tab_container";
import OverviewTabContainer from "../containers/overview_tab_container";
import SpeciesTabContainer from "../containers/species_tab_container";
import StatsTabContainer from "../containers/stats_tab_container";
import StatsHeaderContainer from "../containers/stats_header_container";
import AboutContainer from "../containers/about_container";
import BeforeEventTabContainer from "../containers/before_event_tab_container";

const App = ( { config, project, subscribe, setSelectedTab } ) => {
  let view;
  let tab = config.selectedTab;
  if ( project.startDate && !project.started && tab !== "about" ) {
    tab = "before_event";
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
    case "stats":
      view = ( <StatsTabContainer /> );
      break;
    case "before_event":
      view = ( <BeforeEventTabContainer /> );
      break;
    case "about":
      return ( <AboutContainer /> );
    default:
      view = project.project_type === "umbrella" ?
        ( <UmbrellaOverviewTabContainer /> ) :
        ( <OverviewTabContainer /> );
  }
  const userIsManager = config.currentUser &&
    _.find( project.admins, a => a.user.id === config.currentUser.id );
  const hasIcon = project.customIcon && project.customIcon( );
  const colorRGB = tinycolor( project.banner_color || "#28387d" ).toRgb( );
  const headerButton = userIsManager ? (
    <a href={ `/projects/${project.slug}/edit` }>
      <button>{ I18n.t( "edit" ) }</button>
    </a> ) : (
    <button onClick={ ( ) => subscribe( ) }>
      { project.currentUserSubscribed ? I18n.t( "unfollow" ) : I18n.t( "follow" ) }
    </button>
  );
  let eventDates;
  if ( project.rule_observed_on && project.startDate ) {
    eventDates = project.startDate.format( "MMM D, YYYY" );
  } else if ( project.rule_d1 && project.rule_d2 && project.startDate && project.endDate ) {
    const start = project.startDate.format( "MMM D, YYYY" );
    const end = project.endDate.format( "MMM D, YYYY" );
    eventDates = `${start} - ${end}`;
  }
  const headerDates = eventDates ? (
    <div className="header-dates">
      { eventDates }
    </div>
  ) : null;
  const headerTitle = project.hide_title ? null : (
    <div className="header-title">
      { hasIcon && (
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
  const headerInProgress = ( project.started && !project.ended ) ? (
    <div className="header-in-progress">
      In Progress
    </div>
  ) : null;
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
              className={ `title-container ${eventDates && "event"} ${hasIcon && "icon"}` }
              style={ project.header_image_url ? {
                backgroundImage: `url( '${project.header_image_url}' )`
              } : {
                background: `rgba(${colorRGB.r},${colorRGB.g},${colorRGB.b},0.2)`
              } }
            >
              { headerTitle }
              { headerDates }
              { headerInProgress }
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
              <div
                className="header-about-read-more"
                onClick={ () => setSelectedTab( "about" ) }
              >
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
      { !( project.startDate && !project.started ) && ( <StatsHeaderContainer /> ) }
      <div className="Content">
        { view }
      </div>
    </div>
  );
};

App.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  subscribe: PropTypes.func,
  setSelectedTab: PropTypes.func
};

export default App;
