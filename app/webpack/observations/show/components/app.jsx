import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col, Button } from "react-bootstrap";
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
import ResearchGradeProgressContainer from "../containers/research_grade_progress_container";
import QualityMetricsContainer from "../containers/quality_metrics_container";
import ConfirmModalContainer from "../containers/confirm_modal_container";

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

const App = ( { observation, config } ) => {
  if ( _.isEmpty( observation ) ) {
    return (
      <div id="initial-loading" className="text-center">
        <div className="loading_spinner" />
      </div>
    );
  }
  const viewerIsObserver = config && config.currentUser &&
    config.currentUser.id === observation.user.id;
  const editButton = (
    viewerIsObserver ?
      <Button bsStyle="primary" className="edit" href={ `/observations/${observation.id}/edit` } >
        Edit Observation
      </Button> : null
  );
  const photosColClass =
    ( ( !observation.photos || observation.photos.length === 0 ) &&
    ( !observation.sounds || observation.sounds.length === 0 ) ) ? "empty" : null;
  const taxonUrl = observation.taxon ? `/taxa/${observation.taxon.id}` : null;
  let warning;
  if ( _.find( observation.flags, f => f.flag === "spam" ) ) {
    /* global SITE */
    warning = (
      <div className="container flash-warning">
        <div className="alert alert-danger">
          <i className="fa fa-flag" />
          <span className="bold">This has been flagged as spam.</span>
          This observation has been flagged as spam and is no longer publicly visible.
          You can see it because you created it, or you are a site curator.
          If you think this is a mistake, please <a
            href={ `mailto:${SITE.help_email}` }
            className="contact"
          >
            contact us
          </a>. <a href={ `/observations/${observation.id}/flags` }>
            Manage flags
          </a>
        </div>
      </div>
    );
  }
  let formattedDateObserved;
  if ( observation.time_observed_at ) {
    formattedDateObserved = moment.tz( observation.time_observed_at,
      observation.observed_time_zone ).format( "MMM D, YYYY · LT z" );
  } else if ( observation.observed_on ) {
    formattedDateObserved = moment( observation.observed_on ).format( "MMM D, YYYY" );
  } else {
    formattedDateObserved = "Not recorded";
  }
  return (
    <div id="ObservationShow">
    { warning }
      <div className="upper">
        <Grid>
          <Row className="title_row">
            <Col xs={10}>
              <div className="ObservationTitle">
                <div className="title">
                  <SplitTaxon taxon={observation.taxon} url={taxonUrl} />
                </div>
                <ConservationStatusBadge observation={ observation } />
                <EstablishmentMeansBadge observation={ observation } />
                <div className="quality_flag">
                  <span className={ `quality_grade ${observation.quality_grade} ` }>
                    { _.upperFirst( I18n.t( observation.quality_grade ) ) }
                  </span>
                </div>
              </div>
            </Col>
            <Col xs={2}>
              { editButton }
            </Col>
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
                    <MapContainer />
                    <Row className="date_row">
                      <Col xs={6}>
                        <span className="bold_label">Observed:</span>
                        <span className="date">
                          { formattedDateObserved }
                        </span>
                      </Col>
                      <Col xs={6}>
                        <span className="bold_label">Submitted:</span>
                        <span className="date">
                          { moment.tz( observation.created_at,
                            observation.created_time_zone ).format( "MMM D, YYYY · LT z" ) }
                        </span>
                      </Col>
                    </Row>
                    <Row className="stats_row">
                      <Col xs={4}>
                        <i className="fa fa-comment" />
                        { observation.comments_count }
                      </Col>
                      <Col xs={4}>
                        <i className="fa fa-tag" />
                        { observation.identifications_count }
                      </Col>
                      <Col xs={4}>
                        <i className="fa fa-star" />
                        { observation.faves.length }
                      </Col>
                    </Row>
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
              <Row>
                <Col xs={12}>
                  <h3>Description</h3>
                  <UserText text={ observation.description } />
                </Col>
              </Row>
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
              <Row>
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
                <Col xs={12} className="Copyright">
                  <h4>Copyright Info</h4>
                  Observation &copy; { observation.user.login } &middot;
                  All Rights Reserved
                </Col>
              </Row>
            </Col>
          </Row>
        </Grid>
      </div>
      <div className="data_quality_assessment">
        <Grid>
          <Row>
            <Col xs={7}>
              <QualityMetricsContainer />
            </Col>
            <Col xs={5}>
              <ResearchGradeProgressContainer />
            </Col>
          </Row>
        </Grid>
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
    </div>
  );
};

App.propTypes = {
  observation: PropTypes.object,
  config: PropTypes.object,
  observation_places: PropTypes.object,
  addComment: PropTypes.func,
  deleteComment: PropTypes.func,
  addID: PropTypes.func,
  deleteID: PropTypes.func,
  restoreID: PropTypes.func
};

export default App;
