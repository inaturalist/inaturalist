import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col, Button, SplitButton, MenuItem } from "react-bootstrap";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserText from "../../../shared/components/user_text";
import PhotoBrowser from "./photo_browser";
import UserWithIcon from "./user_with_icon";
import ConservationStatusBadge from "../components/conservation_status_badge";
import EstablishmentMeansBadge from "../components/establishment_means_badge";
import ActivityContainer from "../containers/activity_container";
import FlaggingModalContainer from "../containers/flagging_modal_container";
import CommunityIDModalContainer from "../containers/community_id_modal_container";
import LicensingModalContainer from "../containers/licensing_modal_container";
import AnnotationsContainer from "../containers/annotations_container";
import CommunityIdentificationContainer from "../containers/community_identification_container";
import TagsContainer from "../containers/tags_container";
import FavesContainer from "../containers/faves_container";
import IdentifiersContainer from "../containers/identifiers_container";
import FollowButtonContainer from "../containers/follow_button_container";
import MapContainer from "../containers/map_container";
import MoreFromUserContainer from "../containers/more_from_user_container";
import NearbyContainer from "../containers/nearby_container";
import ObservationFieldsContainer from "../containers/observation_fields_container";
import SimilarContainer from "../containers/similar_container";
import ProjectsContainer from "../containers/projects_container";
import ConfirmModalContainer from "../containers/confirm_modal_container";
import CopyrightContainer from "../containers/copyright_container";
import AssessmentContainer from "../containers/assessment_container";
import FlashMessage from "../components/flash_message";
/* global RAILS_FLASH */

moment.locale( "en", {
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

const App = ( {
  observation, config, controlledTerms, leaveTestGroup, deleteObservation, setLicensingModalState
} ) => {
  if ( _.isEmpty( observation ) || _.isEmpty( observation.user ) ) {
    return (
      <div id="initial-loading" className="text-center">
        <div className="loading_spinner" />
      </div>
    );
  }
  const viewerIsObserver = config && config.currentUser &&
    config.currentUser.id === observation.user.id;
  const photosColClass =
    ( ( !observation.photos || observation.photos.length === 0 ) &&
    ( !observation.sounds || observation.sounds.length === 0 ) ) ? "empty" : null;
  const taxonUrl = observation.taxon ? `/taxa/${observation.taxon.id}` : null;
  let flashes = [];
  if ( !_.isEmpty( RAILS_FLASH ) ) {
    const types = [
      { flashType: "notice", bootstrapType: "success" },
      { flashType: "alert", bootstrapType: "success" },
      { flashType: "warning", bootstrapType: "warning" },
      { flashType: "error", bootstrapType: "error" }
    ];
    _.each( types, type => {
      if ( RAILS_FLASH[type.flashType] &&
           RAILS_FLASH[`${[type.flashType]}_title`] !==
             I18n.t( "views.shared.spam.this_has_been_flagged_as_spam" ) ) {
        flashes.push( <FlashMessage
          key={ `flash_${type.flashType}`}
          title={ RAILS_FLASH[`${[type.flashType]}_title`] }
          message={ RAILS_FLASH[type.flashType] }
          type={ type.bootstrapType }
        /> );
      }
    } );
  }
  const unresolvedFlags = _.filter( observation.flags || [], f => !f.resolved );
  if ( _.find( unresolvedFlags, f => f.flag === "spam" ) ) {
    /* global SITE */
    const message = (
      <span>
        This observation has been flagged as spam and is no longer
        publicly visible. You can see it because you created it, or you are a
        site curator. If you think this is a mistake, please <a
          href={ `mailto:${SITE.help_email}` }
          className="contact"
        >
          contact us
        </a>. <a href={ `/observations/${observation.id}/flags` }>
          Manage flags
        </a>
      </span>
    );
    flashes.push( <FlashMessage
      key="flash_flag"
      title = { I18n.t( "views.shared.spam.this_has_been_flagged_as_spam" ) }
      message={ message }
      type="flag"
    /> );
  }
  let formattedDateObserved;
  if ( observation.time_observed_at ) {
    formattedDateObserved = moment.tz( observation.time_observed_at,
      observation.observed_time_zone ).format( "MMM D, YYYY · LT z" );
  } else if ( observation.observed_on ) {
    formattedDateObserved = moment( observation.observed_on ).format( "MMM D, YYYY" );
  } else {
    formattedDateObserved = I18n.t( "not_recorded" );
  }
  const description = observation.description ? (
    <Row>
      <Col xs={12}>
        <h3>{ I18n.t( "description" ) }</h3>
        <UserText text={ observation.description } />
      </Col>
    </Row> ) : "";
  return (
    <div id="ObservationShow">
    { flashes }
      <div className="upper">
        <Grid>
          <Row className="title_row">
            <Col xs={ viewerIsObserver ? 10 : 12 }>
              <div className="ObservationTitle">
                <SplitTaxon
                  taxon={ observation.taxon }
                  url={ taxonUrl }
                  placeholder={observation.species_guess}
                />
                <ConservationStatusBadge observation={ observation } />
                <EstablishmentMeansBadge observation={ observation } />
                <span className={ `quality_grade ${observation.quality_grade} ` }>
                  { _.upperFirst( I18n.t( observation.quality_grade ) ) }
                </span>
              </div>
            </Col>
            { viewerIsObserver ? (
              <Col xs={2} className="edit-button">
                <SplitButton
                  bsStyle="primary"
                  className="edit"
                  href={ `/observations/${observation.id}/edit` }
                  title={ I18n.t( "edit" ) }
                  id="edit-dropdown"
                  pullRight
                  onSelect={ ( event, key ) => {
                    if ( key === "delete" ) {
                      deleteObservation( );
                    } else if ( key === "license" ) {
                      setLicensingModalState( { show: true } );
                    }
                  } }
                >
                  <MenuItem eventKey="delete">
                    <i className="fa fa-trash" />
                    Delete
                  </MenuItem>
                  <MenuItem
                    eventKey="duplicate"
                    href={ `/observations/new?copy=${observation.id}` }
                  >
                    <i className="fa fa-files-o" />
                    Duplicate
                  </MenuItem>
                  <MenuItem eventKey="license">
                    <i className="fa fa-copyright" />
                    Edit Licensing
                  </MenuItem>
                </SplitButton>
              </Col> ) : ""
            }
          </Row>
          <Row>
            <Col xs={12}>
              <Grid className="top_container">
                <Row className="top_row">
                  <Col xs={7} className={ `photos_column ${photosColClass}` }>
                    <PhotoBrowser observation={observation} />
                  </Col>
                  <Col xs={5} className="info_column">
                    <div className="user_info">
                      { !viewerIsObserver ? ( <FollowButtonContainer /> ) : null }
                      <UserWithIcon user={ observation.user } />
                    </div>
                    <Row className="date_row">
                      <Col xs={6}>
                        <span className="bold_label">{ I18n.t( "observed" ) }:</span>
                        <span className="date">
                          { formattedDateObserved }
                        </span>
                      </Col>
                      <Col xs={6}>
                        <span className="bold_label">{ I18n.t( "submitted" ) }:</span>
                        <span className="date">
                          { moment.tz( observation.created_at,
                            observation.created_time_zone ).format( "MMM D, YYYY · LT z" ) }
                        </span>
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
                <Col xs={12}>
                  <AnnotationsContainer />
                </Col>
              </Row>
              <Row className={ _.isEmpty( controlledTerms ) ? "top-row" : "" }>
                <Col xs={12}>
                  <ProjectsContainer />
                </Col>
              </Row>
              <Row>
                <Col xs={12}>
                  <TagsContainer />
                </Col>
              </Row>
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
        <AssessmentContainer />
      </div>
      <div className="more_from">
        <Grid>
          <Row>
            <Col xs={12}>
              <MoreFromUserContainer />
            </Col>
          </Row>
        </Grid>
      </div>
      <div className="other_observations">
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
      <FlaggingModalContainer />
      <ConfirmModalContainer />
      <CommunityIDModalContainer />
      <LicensingModalContainer />
      <div className="quiet box text-center opt-out">
        { I18n.t( "tired_of_testing_this_new_version" ) }
        <Button bsStyle="primary" onClick={ () => leaveTestGroup( "obs-show" ) }>
          { I18n.t( "take_me_back" ) }
        </Button>
      </div>
    </div>
  );
};

App.propTypes = {
  config: PropTypes.object,
  controlledTerms: PropTypes.array,
  leaveTestGroup: PropTypes.func,
  observation: PropTypes.object,
  deleteObservation: PropTypes.func,
  setLicensingModalState: PropTypes.func
};

export default App;
