import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
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
import InsufficientRequirementsContainer from "../containers/insufficient_requirements_container";
import ConfirmModalContainer from "../../shared/containers/confirm_modal_container";
import FlagAnItemContainer from "../../../shared/containers/flag_an_item_container";
import FlaggingModalContainer from "../containers/flagging_modal_container";
import UsersPopover from "../../../observations/show/components/users_popover";
import FlashMessagesContainer from "../../../shared/containers/flash_messages_container";
import ProjectMembershipButtonContainer from "../containers/project_membership_button_container";
import FlashMessage from "../../../observations/show/components/flash_message";
import TestGroupToggle from "../../../shared/components/test_group_toggle";

const App = ( {
  config, project, leave, setSelectedTab, convertProject
} ) => {
  let view;
  let tab = config.selectedTab;
  const showingCountdown = ( project.startDate && !project.started && tab !== "about"
    && !( project.recent_observations && !_.isEmpty( project.recent_observations.results ) ) );
  if ( showingCountdown ) {
    tab = "before_event";
  }
  if ( project.hasInsufficientRequirements( ) && tab !== "about" ) {
    tab = "insufficient_requirements";
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
    case "insufficient_requirements":
      view = ( <InsufficientRequirementsContainer /> );
      break;
    case "about":
      return ( <AboutContainer /> );
    default:
      view = project.project_type === "umbrella"
        ? ( <UmbrellaOverviewTabContainer /> )
        : ( <OverviewTabContainer /> );
  }
  const loggedIn = config.currentUser;
  const userIsOwner = loggedIn && config.currentUser.id === project.user_id;
  const userIsManager = loggedIn
    && _.find( project.admins, a => a.user.id === config.currentUser.id );
  const viewerIsAdmin = loggedIn && config.currentUser.roles
    && config.currentUser.roles.indexOf( "admin" ) >= 0;
  const hasIcon = !project.hide_title && project.customIcon && project.customIcon( );
  const hasBanner = !!project.header_image_url;
  const colorRGB = tinycolor( project.banner_color || "#28387d" ).toRgb( );
  let membershipLabel;
  if ( loggedIn && !userIsOwner ) {
    if ( project.membership_status === "saving" ) {
      membershipLabel = ( <div className="loading_spinner" /> );
    } else {
      membershipLabel = project.currentUserIsMember ? I18n.t( "leave" ) : I18n.t( "join" );
    }
  } else {
    membershipLabel = I18n.t( "members" );
  }

  let membershipAction;
  if ( loggedIn && !userIsOwner ) {
    if ( project.currentUserIsMember ) {
      membershipAction = ( ) => { leave( ); };
    } else {
      membershipAction = ( ) => {
        window.location = `/projects/${project.slug}/join`;
      };
    }
  } else {
    membershipAction = ( ) => {
      $( ".header-members-button .UsersPopover" ).click( );
    };
  }

  const headerButton = (
    <div className="header-members-button">
      <button
        type="button"
        className="btn btn-nostyle action clicky"
        onClick={membershipAction}
      >
        { membershipLabel }
      </button>
      <UsersPopover
        users={project.members_loaded
          ? _.compact( _.map( project.members.results, "user" ) ) : null}
        keyPrefix="members-popover"
        placement="bottom"
        containerPadding={20}
        returnContentsWhenEmpty
        contentAfterUsers={(
          <div className="view-all-members">
            <a href={`/projects/${project.slug}/members`} className="linky">
              { I18n.t( "view_all_members" ) }
            </a>
          </div>
        )}
        contents={(
          <div className="count">
            <i className="fa fa-user" />
            { project.members_loaded ? project.members.total_results : "---" }
          </div>
        )}
      />
    </div>
  );
  let eventDates;
  if ( project.rule_observed_on && project.startDate ) {
    eventDates = project.startDate.format( "MMM D, YYYY" );
  } else if ( project.rule_d1 && project.rule_d2 && project.startDate && project.endDate ) {
    const start = project.startDate.format( "MMM D, YYYY" );
    const end = project.endDate.format( "MMM D, YYYY" );
    eventDates = I18n.t( "date_to_date", { d1: start, d2: end } );
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
          style={{ backgroundImage: `url( '${project.icon}' )` }}
        />
      ) }
      <div className="title-text">
        { project.title }
      </div>
    </div>
  );
  const inProgress = ( project.startDate && !showingCountdown ) && !project.ended;
  const headerInProgress = inProgress ? (
    <div className="header-in-progress">
      { I18n.t( "event_in_progress" ) }
    </div>
  ) : null;
  let bannerContainer = (
    <Col
      xs={hasBanner ? 12 : 8}
      className={
        `title-container ${eventDates && "event"} ${hasIcon && "icon"} ${!hasBanner && "no-banner"}`
      }
      style={project.header_image_url ? {
        backgroundImage: `url( '${project.header_image_url}' )`,
        backgroundSize: project.header_image_contain ? "contain" : "cover"
      } : {
        backgroundColor: `rgba(${colorRGB.r},${colorRGB.g},${colorRGB.b},0.6)`
      }}
    >
      { headerTitle }
      { headerDates }
      { headerInProgress }
    </Col>
  );
  if ( hasBanner ) {
    // when there is a banner, create an additional container with a solid background
    bannerContainer = (
      <Col
        xs={8}
        className="title-container background"
        style={{ backgroundColor: `rgba(${colorRGB.r},${colorRGB.g},${colorRGB.b},1)` }}
      >
        { bannerContainer }
      </Col>
    );
  }
  const userCanEdit = ( userIsManager || viewerIsAdmin );
  return (
    <div id="ProjectsShow">
      { project.is_traditional && (
        <Grid>
          <Row>
            <Col xs={12}>
              <div className="box text-center upstacked">
                { I18n.t( "views.projects.show.this_is_a_preview" ) }
                { ( userIsManager || viewerIsAdmin ) && (
                  <div>
                    <button
                      type="button"
                      onClick={convertProject}
                      className="btn btn-nostyle linky"
                    >
                      { I18n.t( "views.projects.show.click_here_to_convert_this_project" ) }
                    </button>
                  </div>
                ) }
              </div>
            </Col>
          </Row>
        </Grid>
      ) }
      { config && config.testingApiV2 && (
        <FlashMessage
          key="testing_apiv2"
          title="Testing API V2"
          message="This page is using V2 of the API. Please report any differences from using the page w/ API v1 at https://forum.inaturalist.org/t/api-v2-feedback/21215"
          type="warning"
          html
        />
      ) }
      <FlashMessagesContainer
        item={project}
        manageFlagsPath={`/flags?project_id=${project.id}`}
      />
      <div className={`project-header ${hasBanner && "with-banner"}`}>
        <div
          className="project-header-background"
          style={project.header_image_url ? {
            backgroundImage: `url( '${project.header_image_url}' )`
          } : null}
        />
        <Grid className="header-grid">
          <Row>
            { bannerContainer }
            <Col
              xs={4}
              className="header-about"
              style={{
                background: `rgba(${colorRGB.r},${colorRGB.g},${colorRGB.b},1)`
              }}
            >
              <div className="header-about-content">
                <div className="header-about-title">
                  { I18n.t( "about" ) }
                </div>
                <div className="header-about-button">
                  { headerButton }
                </div>
                <div className="header-about-text">
                  <UserText
                    text={project.description}
                    truncate={500}
                    moreToggle={false}
                  />
                </div>
                <div>
                  <button
                    type="button"
                    className="header-about-read-more header-link-btn btn btn-nostyle"
                    onClick={() => setSelectedTab( "about" )}
                  >
                    { I18n.t( "read_more" ) }
                    <i className="fa fa-chevron-right" />
                  </button>
                  <div className="pull-right">
                    <ProjectMembershipButtonContainer />
                  </div>
                </div>
                <div>
                  { userCanEdit && (
                    <div className="header-about-edit">
                      <a href={`/projects/${project.slug}/edit`} className="btn btn-default btn-white">
                        <i className="fa fa-cog" />
                        { I18n.t( "edit_project" ) }
                      </a>
                    </div>
                  ) }
                  { !userCanEdit && project.rule_members_only && (
                    <div className="header-about-members-only">
                      { I18n.t( "project_members_only" ) }
                    </div>
                  ) }
                  <div className="header-about-news">
                    <a href={`/projects/${project.slug}/journal`}>
                      <span className="glyphicon glyphicon-book" />
                      { I18n.t( "project_journal" ) }
                    </a>
                  </div>
                </div>
              </div>
            </Col>
          </Row>
        </Grid>
      </div>
      { !showingCountdown && !project.hasInsufficientRequirements( )
        && ( <StatsHeaderContainer /> ) }
      <div className="Content">
        { view }
        <Grid>
          <Row>
            <Col xs={12}>
              <FlagAnItemContainer
                item={project}
                itemTypeLabel={I18n.t( "project" )}
                manageFlagsPath={`/projects/${project.id}/flags`}
              />
            </Col>
          </Row>
        </Grid>
      </div>
      <FlaggingModalContainer />
      <ConfirmModalContainer />
      {
        config && config.currentUser
        && (
          config.currentUser.roles.indexOf( "curator" ) >= 0
          || config.currentUser.roles.indexOf( "admin" ) >= 0
          || config.currentUser.sites_admined.length > 0
        )
        && (
          <div className="container upstacked">
            <div className="row">
              <div className="cols-xs-12">
                <TestGroupToggle
                  group="apiv2"
                  joinPrompt="Test API V2? You can also use the test=apiv2 URL param"
                  joinedStatus="Joined API V2 test"
                  user={config.currentUser}
                />
              </div>
            </div>
          </div>
        )
      }
    </div>
  );
};

App.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  leave: PropTypes.func,
  setSelectedTab: PropTypes.func,
  convertProject: PropTypes.func
};

export default App;
