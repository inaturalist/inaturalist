import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import tinycolor from "tinycolor2";
import UserText from "../../../shared/components/user_text";
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
import ConfirmModalContainer from "../../shared/containers/confirm_modal_container";
import UsersPopover from "../../../observations/show/components/users_popover";

const App = ( { config, project, subscribe, setSelectedTab, convertProject } ) => {
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
  const loggedIn = config.currentUser;
  const userIsManager = loggedIn &&
    _.find( project.admins, a => a.user.id === config.currentUser.id );
  const viewerIsAdmin = loggedIn && config.currentUser.roles &&
    config.currentUser.roles.indexOf( "admin" ) >= 0;
  const hasIcon = !project.hide_title && project.customIcon && project.customIcon( );
  const hasBanner = !!project.header_image_url;
  const colorRGB = tinycolor( project.banner_color || "#28387d" ).toRgb( );
  let followLabel;
  if ( loggedIn ) {
    if ( project.follow_status === "saving" ) {
      followLabel = ( <div className="loading_spinner" /> );
    } else {
      followLabel = project.currentUserSubscribed ? I18n.t( "unfollow" ) : I18n.t( "follow" );
    }
  } else {
    followLabel = I18n.t( "followers" );
  }
  const headerButton = (
    <div className="header-followers-button">
      <div
        className={ `action ${loggedIn && "clicky"}` }
        onClick={ ( ) => {
          if ( loggedIn ) {
            subscribe( );
          }
        } }
      >
        { followLabel }
      </div>
      <UsersPopover
        users={ project.followers_loaded ?
          _.compact( _.map( project.followers.results, "user" ) ) : null }
        keyPrefix="followers-popover"
        placement="bottom"
        contents={ (
          <div className="count">
            <i className="fa fa-user" />
            { project.followers_loaded ? project.followers.total_results : "---" }
          </div>
        ) }
      />
    </div>
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
      { I18n.t( "event_in_progress" ) }
    </div>
  ) : null;
  return (
    <div id="ProjectsShow">
      { project.is_traditional && (
        <Grid>
          <Row>
            <Col xs={ 12 }>
              <div className="box text-center upstacked">
                This is a preview.
                { ( userIsManager || viewerIsAdmin ) && (
                  <div>
                    <a onClick={ convertProject } className="linky">
                      Click here to convert this project
                    </a>
                    <ConfirmModalContainer />
                  </div>
                ) }
              </div>
            </Col>
          </Row>
        </Grid>
      ) }
      <div className={ `project-header ${hasBanner && "with-banner"}` }>
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
              className={
                `title-container ${eventDates && "event"} ${hasIcon && "icon"} ${!hasBanner && "no-banner"}`
              }
              style={ project.header_image_url ? {
                backgroundImage: `url( '${project.header_image_url}' )`
              } : {
                backgroundColor: `rgba(${colorRGB.r},${colorRGB.g},${colorRGB.b},0.6)`
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
              <div className="header-about-content">
                <div className="header-about-title">
                  { I18n.t( "about" ) }
                </div>
                { !project.is_traditional && (
                  <div className="header-about-button">
                    { headerButton }
                  </div>
                ) }
                <div className="header-about-text">
                  <UserText
                    text={ project.description }
                    truncate={ 500 }
                    moreToggle={ false }
                  />
                </div>
                <div
                  className="header-about-read-more"
                  onClick={ () => setSelectedTab( "about" ) }
                >
                  { I18n.t( "read_more" ) }
                  <i className="fa fa-chevron-right" />
                </div>
                { ( userIsManager || viewerIsAdmin ) && (
                  <div className="header-about-edit">
                    <a href={ `/projects/${project.slug}/edit` }>
                      <button className="btn btn-default btn-white">
                        <i className="fa fa-cog" />
                        { I18n.t( "edit_project" ) }
                      </button>
                    </a>
                  </div>
                ) }
                <div className="header-about-news">
                  <a href={ `/projects/${project.slug}/journal` }>
                    <i className="fa fa-bell" />
                    { I18n.t( "news" ) }
                  </a>
                </div>
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
  setSelectedTab: PropTypes.func,
  convertProject: PropTypes.func
};

export default App;
