import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import {
  Grid,
  Row,
  Col,
  SplitButton,
  MenuItem,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserText from "../../../shared/components/user_text";
import Inativersary from "../../../shared/components/inativersary";
import { formattedDateTimeInTimeZone } from "../../../shared/util";
import UserWithIcon from "./user_with_icon";
import FlashMessagesContainer from "../../../shared/containers/flash_messages_container";
import ConservationStatusBadge from "./conservation_status_badge";
import EstablishmentMeansBadge from "./establishment_means_badge";
import ActivityContainer from "../containers/activity_container";
import AnnotationsContainer from "../containers/annotations_container";
import AssessmentContainer from "../containers/assessment_container";
import CommunityIdentificationContainer from "../containers/community_identification_container";
import CommunityIDModalContainer from "../containers/community_id_modal_container";
import ConfirmModalContainer from "../../../shared/containers/confirm_modal_container";
import DisagreementAlertContainer from "../containers/disagreement_alert_container";
import CopyrightContainer from "../containers/copyright_container";
import FavesContainer from "../containers/faves_container";
import FlaggingModalContainer from "../containers/flagging_modal_container";
import FollowButtonContainer from "../containers/follow_button_container";
import IdentifiersContainer from "../containers/identifiers_container";
import LicensingModalContainer from "../containers/licensing_modal_container";
import MapContainer from "../containers/map_container";
import MediaViewerContainer from "../containers/media_viewer_container";
import MoreFromUserContainer from "../containers/more_from_user_container";
import NearbyContainer from "../containers/nearby_container";
import ObservationFieldsContainer from "../containers/observation_fields_container";
import PhotoBrowserContainer from "../containers/photo_browser_container";
import PreviousNextButtonsContainer from "../containers/previous_next_buttons_container";
import ProjectFieldsModalContainer from "../containers/project_fields_modal_container";
import ProjectsContainer from "../containers/projects_container";
import SimilarContainer from "../containers/similar_container";
import TagsContainer from "../containers/tags_container";
import ModeratorActionModalContainer from "../containers/moderator_action_modal_container";
import ObservationModalContainer from "../containers/observation_modal_container";
import TestGroupToggle from "../../../shared/components/test_group_toggle";
import RtlTestGroupToggle from "../../../shared/components/rtl_test_group_toggle";
import FlashMessage from "./flash_message";
import AssessmentLazyLoad from "./assessment_lazy_load";

moment.updateLocale( "en", {
  relativeTime: {
    future: "in %s",
    past: "%s",
    s: "%ds",
    m: "1m",
    mm: "%dm",
    h: "1h",
    hh: "%dh",
    d: "1d",
    dd: "%dd",
    M: "1mo",
    MM: "%dmo",
    y: "1y",
    yy: "%dy"
  }
} );

class App extends React.Component {
  linkDateToObservationSearch( dateString, searchParameters = { } ) {
    if ( _.isEmpty( dateString ) ) {
      return null;
    }

    const { observation } = this.props;
    let url = `/observations?user_id=${observation.user.login}&place_id=any&verifiable=any&`;
    url += $.param( _.pickBy( searchParameters, v => !_.isNil( v ) ) );
    // dates are formatted with the `momentjs.datetime_with_offset` pattern. Currently
    // all locales separate the date part of the string from the time and zone part of
    // the string with an mdot followed by LT Z. Use that pattern to split the string
    // to attempt to only link the date and not the time. If the pattern is not found
    // (as would be the case when there is no time) link the entire string to the search
    if ( I18n.t( "momentjs.datetime_with_offset" )?.match( / · LT Z$/ )
      && dateString.match( / · / ) ) {
      const dateComponents = dateString.split( " · " );
      return (
        <span>
          <a href={url}>{dateComponents[0]}</a>
          {" · "}
          {dateComponents[1]}
        </span>
      );
    }
    return (
      <a href={url}>{dateString}</a>
    );
  }

  displayDateObserved( ) {
    const { observation } = this.props;
    const observedAt = moment( observation.time_observed_at || observation.observed_on );
    let isoDateObserved = observedAt.format( );
    let observedYear;
    let observedMonth;
    let observedDay;
    let formattedDateObserved;

    if ( observation.observed_on ) {
      observedYear = observation.observed_on_details.year;
      observedMonth = observation.observed_on_details.month;
      observedDay = observation.observed_on_details.day;
      if (
        observation.obscured
        && !observation.private_geojson
      ) {
        formattedDateObserved = observedAt.format( I18n.t( "momentjs.month_year" ) );
        isoDateObserved = observedAt.format( "YYYY-MM" );
        observedDay = null;
      } else if ( observation.time_observed_at ) {
        formattedDateObserved = formattedDateTimeInTimeZone(
          observation.time_observed_at,
          observation.observed_time_zone
        );
      } else {
        formattedDateObserved = observedAt.format( "ll" );
      }
    }

    const searchParameters = observedYear && observedMonth && observedDay ? {
      on: `${observedYear}-${observedMonth}-${observedDay}`
    } : {
      year: observedYear,
      month: observedMonth,
      day: observedDay
    };
    return (
      <span className="date" title={isoDateObserved}>
        { observation.observed_on
          && observation.obscured
          && !observation.private_geojson
          && <i className="icon-icn-location-obscured" title={I18n.t( "date_obscured_notice" )} /> }
        { this.linkDateToObservationSearch( formattedDateObserved, searchParameters )
          || I18n.t( "missing_date" ) }
      </span>
    );
  }

  displayDateAdded( ) {
    const { observation, config } = this.props;
    let viewerTimeZone = moment.tz.guess();
    if ( config && config.currentUser && config.currentUser.time_zone ) {
      viewerTimeZone = config.currentUser.time_zone;
    }
    const createdAt = moment( observation.created_at );
    let isoDateAdded = createdAt.format( );
    const addedYear = observation.created_at_details.year;
    const addedMonth = observation.created_at_details.month;
    let addedDay = observation.created_at_details.day;
    let formattedDateAdded = formattedDateTimeInTimeZone(
      moment.tz(
        observation.created_at,
        observation.created_time_zone
      ),
      viewerTimeZone
    );

    if (
      observation.obscured
      && !observation.private_geojson
    ) {
      formattedDateAdded = createdAt.format( I18n.t( "momentjs.month_year" ) );
      isoDateAdded = createdAt.format( "YYYY-MM" );
      addedDay = null;
    }

    const searchParameters = addedYear && addedMonth && addedDay ? {
      created_on: `${addedYear}-${addedMonth}-${addedDay}`
    } : {
      created_year: addedYear,
      created_month: addedMonth,
      created_day: addedDay
    };
    return (
      <span className="date" title={isoDateAdded}>
        { observation.obscured
          && !observation.private_geojson
          && <i className="icon-icn-location-obscured" title={I18n.t( "date_obscured_notice" )} /> }
        { this.linkDateToObservationSearch( formattedDateAdded, searchParameters ) }
      </span>
    );
  }

  render( ) {
    const {
      observation,
      config,
      deleteObservation,
      setLicensingModalState
    } = this.props;
    if ( _.isEmpty( observation ) || _.isEmpty( observation.user ) ) {
      return (
        <div id="initial-loading" className="text-center">
          <div className="loading_spinner" />
        </div>
      );
    }
    const viewerIsObserver = config && config.currentUser
      && config.currentUser.id === observation.user.id;
    const photosColClass = (
      ( !observation.photos || observation.photos.length === 0 )
      && ( !observation.sounds || observation.sounds.length === 0 )
    ) ? "empty" : null;
    const taxonUrl = observation.taxon ? `/taxa/${observation.taxon.id}` : null;
    const description = observation.description
      ? (
        <Row>
          <Col xs={12}>
            <h3>
              {
                I18n.t( "notes", {
                  defaultValue: I18n.t( "activerecord.attributes.observation.description" )
                } )
              }
            </h3>
            <UserText text={observation.description} />
          </Col>
        </Row>
      )
      : "";
    const qualityGrade = observation.quality_grade === "research"
      ? "research_grade"
      : observation.quality_grade;
    let qualityGradeTooltipHtml;
    if ( qualityGrade === "casual" ) {
      qualityGradeTooltipHtml = I18n.t( "casual_tooltip_html" );
    } else if ( qualityGrade === "needs_id" ) {
      qualityGradeTooltipHtml = I18n.t( "needs_id_tooltip_html" );
    } else {
      qualityGradeTooltipHtml = I18n.t( "research_grade_tooltip_html" );
    }

    return (
      <div id="ObservationShow">
        { config && config.testingApiV2 && (
          <FlashMessage
            key="testing_apiv2"
            title="Testing API V2"
            message="This page is using V2 of the API. Please report any differences from using the page w/ API v1 at https://forum.inaturalist.org/t/v2-feedback/21215"
            type="warning"
            html
          />
        ) }
        <FlashMessagesContainer
          item={observation}
          manageFlagsPath={`/observations/${observation.id}/flags`}
          showBlocks
        />
        <div className="upper">
          <Grid>
            <Row className="title_row">
              <Col xs={10}>
                <div className="ObservationTitle">
                  <SplitTaxon
                    taxon={observation.taxon}
                    url={taxonUrl}
                    placeholder={observation.species_guess}
                    user={config.currentUser}
                  />
                  <ConservationStatusBadge observation={observation} />
                  <EstablishmentMeansBadge observation={observation} />
                  <OverlayTrigger
                    placement="bottom"
                    trigger={["hover", "click"]}
                    delayHide={1000}
                    overlay={(
                      <Tooltip id="quality-grade-tooltip">
                        <p
                          // eslint-disable-next-line react/no-danger
                          dangerouslySetInnerHTML={{ __html: qualityGradeTooltipHtml }}
                        />
                      </Tooltip>
                    )}
                    container={$( "#wrapper.bootstrap" ).get( 0 )}
                  >
                    <span className={`quality_grade ${observation.quality_grade} `}>
                      { I18n.t( `${qualityGrade}_`, { defaultValue: I18n.t( qualityGrade ) } ) }
                    </span>
                  </OverlayTrigger>
                </div>
              </Col>
              { viewerIsObserver
                ? (
                  <Col xs={2} className="edit-button">
                    <SplitButton
                      bsStyle="primary"
                      className="edit"
                      href={`/observations/${observation.id}/edit`}
                      title={I18n.t( "edit" )}
                      id="edit-dropdown"
                      pullRight
                      onSelect={key => {
                        if ( key === "delete" ) {
                          deleteObservation( );
                        } else if ( key === "license" ) {
                          setLicensingModalState( { show: true } );
                        }
                      }}
                    >
                      <MenuItem
                        eventKey="edit"
                        href={`/observations/${observation.id}/edit`}
                      >
                        <i className="fa fa-pencil" />
                        { I18n.t( "edit" ) }
                      </MenuItem>
                      <MenuItem
                        eventKey="duplicate"
                        href={`/observations/new?copy=${observation.id}`}
                      >
                        <i className="fa fa-files-o" />
                        { I18n.t( "duplicate_verb" ) }
                      </MenuItem>
                      <MenuItem eventKey="license">
                        <i className="fa fa-copyright" />
                        { I18n.t( "edit_license" ) }
                      </MenuItem>
                      <li role="separator" className="divider" />
                      <MenuItem eventKey="delete">
                        <i className="fa fa-trash" />
                        { I18n.t( "delete" ) }
                      </MenuItem>
                    </SplitButton>
                  </Col>
                ) : config?.currentUserCanInteractWithResource( observation ) && ( <FollowButtonContainer /> ) }
            </Row>
            <Row>
              <Col xs={12}>
                <Grid className="top_container">
                  <Row className="top_row">
                    <Col xs={7} className={`photos_column ${photosColClass}`}>
                      <PhotoBrowserContainer />
                    </Col>
                    <Col xs={5} className="info_column">
                      <div className="user_info">
                        <PreviousNextButtonsContainer />
                        <UserWithIcon
                          user={observation.user}
                          hideSubtitle={
                            observation.obscured
                            && !observation.private_geojson
                          }
                        />
                      </div>
                      <Row className="date_row">
                        <Col xs={6}>
                          <span className="bold_label">{ I18n.t( "label_colon", { label: I18n.t( "observed" ) } ) }</span>
                          {this.displayDateObserved( )}
                          <Inativersary
                            user={observation.user}
                            date={observation.observed_on}
                            uniqueKey="DateObserved"
                            text={`${observation.user.login} observed this on their iNativersary!`}
                          />
                        </Col>
                        <Col xs={6}>
                          <span className="bold_label">{ I18n.t( "label_colon", { label: I18n.t( "submitted" ) } ) }</span>
                          {this.displayDateAdded( )}
                        </Col>
                      </Row>
                      <MapContainer />
                      <Row className="faves_row">
                        <Col xs={12}>
                          <FavesContainer />
                        </Col>
                      </Row>
                    </Col>
                  </Row>
                </Grid>
              </Col>
            </Row>
            <Row>
              <Col xs={7} className="middle_left">
                { description }
                <Row>
                  <Col xs={12}>
                    <ActivityContainer />
                  </Col>
                </Row>
              </Col>
              <Col xs={5} className="opposite_activity">
                <Row>
                  <Col xs={12}>
                    <CommunityIdentificationContainer />
                  </Col>
                </Row>
                <Row>
                  <LazyLoad
                    debounce={false}
                    offset={100}
                    height={30}
                  >
                    <Col xs={12}>
                      <AnnotationsContainer key={`activity-panel-${observation.uuid}`} />
                    </Col>
                  </LazyLoad>
                </Row>
                <Row>
                  <Col xs={12}>
                    <ProjectsContainer />
                  </Col>
                </Row>
                { (
                  ( config.currentUser && config.currentUser.id === observation.user.id )
                  || ( observation && observation.tags && observation.tags.length > 0 )
                ) && (
                  <Row>
                    <Col xs={12}>
                      <TagsContainer />
                    </Col>
                  </Row>
                ) }
                <Row>
                  <Col xs={12}>
                    <ObservationFieldsContainer />
                  </Col>
                </Row>
                <Row>
                  <Col xs={12}>
                    <IdentifiersContainer />
                  </Col>
                </Row>
                <Row>
                  <Col xs={12}>
                    <CopyrightContainer />
                  </Col>
                </Row>
              </Col>
            </Row>
          </Grid>
        </div>
        <div className="data_quality_assessment">
          <AssessmentContainer innerWrapper={AssessmentLazyLoad} />
        </div>
        { ( !observation.obscured || observation.private_geojson ) && (
          <LazyLoad debounce={false} height={515} offset={500}>
            <div className="more_from">
              <Grid>
                <Row>
                  <Col xs={12}>
                    <MoreFromUserContainer />
                  </Col>
                </Row>
              </Grid>
              <Grid>
                <Row>
                  <Col xs={6}>
                    <NearbyContainer />
                  </Col>
                  <Col xs={6}>
                    <SimilarContainer />
                  </Col>
                </Row>
              </Grid>
            </div>
          </LazyLoad>
        ) }
        <FlaggingModalContainer />
        <ConfirmModalContainer />
        <DisagreementAlertContainer />
        <CommunityIDModalContainer />
        <LicensingModalContainer />
        <MediaViewerContainer />
        <ProjectFieldsModalContainer />
        <ObservationModalContainer />
        <ModeratorActionModalContainer />
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
        <RtlTestGroupToggle config={config} />
      </div>
    );
  }
};

App.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  deleteObservation: PropTypes.func,
  setLicensingModalState: PropTypes.func
};

export default App;
