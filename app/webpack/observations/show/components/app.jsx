import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col, Button, Tabs, Tab, Dropdown } from "react-bootstrap";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonAutocomplete from "../../uploader/components/taxon_autocomplete";
import TaxonMap from "../../identify/components/taxon_map";
import UserImage from "../../identify/components/user_image";
import PhotoBrowser from "./photo_browser";
import UserWithIcon from "./user_with_icon";
import FollowButton from "./follow_button";
import ActivityItem from "./activity_item";
import MapDetails from "./map_details";
import AnnotationsContainer from "../containers/annotations_container";
import TagsContainer from "../containers/tags_container";
import FavesContainer from "../containers/faves_container";
import MoreFromUserContainer from "../containers/more_from_user_container";
import NearbyContainer from "../containers/nearby_container";
import SimilarContainer from "../containers/similar_container";
import ProjectsContainer from "../containers/projects_container";
import QualityMetricsContainer from "../containers/quality_metrics_container";

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

const App = ( { observation, config, addComment, deleteComment, addID, deleteID, restoreID,
  observationPlaces, followUser, unfollowUser, subscribe } ) => {
  if ( _.isEmpty( observation ) ) {
    return (
      <div id="initial-loading" className="text-center">
        <span className="bigloading loading status">Loading...</span>
      </div>
    );
  }
  let taxonMap;
  if ( observation.latitude ) {
    // Select a small set of attributes that won't change wildy as the
    // observation changes.
    const obsForMap = _.pick( observation, [
      "id",
      "species_guess",
      "latitude",
      "longitude",
      "positional_accuracy",
      "geoprivacy",
      "taxon",
      "user"
    ] );
    obsForMap.coordinates_obscured = observation.obscured;
    taxonMap = (
      <TaxonMap
        key={`map-for-${observation.id}`}
        taxonLayers={[{
          taxon: obsForMap.taxon,
          observations: { observation_id: obsForMap.id },
          places: { disabled: true },
          gbif: { disabled: true }
        }] }
        observations={[obsForMap]}
        zoomLevel={ observation.map_scale || 8 }
        mapTypeControl={false}
        showAccuracy
        showAllLayer={false}
        scrollwheel={false}
        overlayMenu
        zoomControlOptions={{ position: google.maps.ControlPosition.TOP_LEFT }}
      />
    );
  }
  const viewerIsObserver = config && config.currentUser &&
    config.currentUser.id === observation.user.id;
  const activity = _.sortBy(
    observation.identifications.concat( observation.comments ), a => (
      moment.parseZone( a.created_at ) ) );
  const editButton = (
    viewerIsObserver ?
      <Button bsStyle="primary" className="edit" href={ `/observations/${observation.id}/edit` } >
        Edit Observation
      </Button> : null
  );
  const photosColClass =
    ( !observation.photos || observation.photos.length === 0 ) ? "empty" : null;
  const tabs = (
    <Tabs defaultActiveKey="comment">
      <Tab eventKey="comment" title="Comment" className="comment_tab">
        <div className="form-group">
          <textarea
            placeholder="Leave a comment"
            className="form-control"
          />
        </div>
      </Tab>
      <Tab eventKey="add_id" title="Suggest an ID" className="id_tab">
        <TaxonAutocomplete
          bootstrap
          searchExternal
          perPage={ 6 }
          resetOnChange={ false }
        />
        <div className="form-group">
          <textarea
            placeholder="Tell us why..."
            className="form-control"
          />
        </div>
      </Tab>
    </Tabs>
  );
  return (
    <div id="ObservationShow">
      <div className="upper">
        <Grid>
          <Row>
            <Col xs={10}>
              <div className="ObservationTitle">
                <div className="title">
                  <SplitTaxon taxon={observation.taxon} url={`/taxa/${observation.taxon.id}`} />
                </div>
                <div className="quality_flag">
                  <span className={ `quality_grade ${observation.quality_grade} ` }>
                    { observation.quality_grade }
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
                      { !viewerIsObserver ? (
                        <FollowButton
                          observation={ observation }
                          followUser={ followUser }
                          unfollowUser={ unfollowUser }
                          subscribe={ subscribe }
                        /> ) : null }
                      <UserWithIcon user={ observation.user } />
                    </div>
                    <div className="obs_map">
                      { taxonMap }
                      <div className="map_details">
                        { observation.place_guess }
                        <div className="details_menu">
                          <Dropdown
                            id="grouping-control"
                          >
                            <Dropdown.Toggle>
                              Details
                            </Dropdown.Toggle>
                            <Dropdown.Menu className="dropdown-menu-right">
                              <li>
                                <MapDetails
                                  observation={ observation }
                                  observationPlaces={ observationPlaces }
                                />
                              </li>
                            </Dropdown.Menu>
                          </Dropdown>
                        </div>
                      </div>
                    </div>
                    <Row className="date_row">
                      <Col xs={6}>
                        <span className="bold_label">Observed:</span>
                        { moment.tz( observation.time_observed_at,
                            observation.observed_time_zone ).format( "lll z" ) }
                      </Col>
                      <Col xs={6}>
                        <span className="bold_label">Submitted:</span>
                        { moment.tz( observation.created_at,
                            observation.created_time_zone ).format( "lll z" ) }
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
                        { observation.faves_count }
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
                  { observation.description }
                </Col>
              </Row>
              <Row>
                <Col xs={12}>
                  <h3>Activity</h3>
                  <div className="activity">
                    { activity.map( item => (
                      <ActivityItem
                        key={ `activity-${item.id}` }
                        item={ item }
                        config={ config }
                        deleteComment={ deleteComment }
                        deleteID={ deleteID }
                        restoreID={ restoreID }
                      /> ) ) }
                    <div className="icon">
                      <UserImage user={ config.currentUser } />
                    </div>
                    <div className="comment_id_panel">
                      { tabs }
                    </div>
                    <Button bsSize="small" onClick={
                      ( ) => {
                        if ( $( ".comment_tab" ).is( ":visible" ) ) {
                          addComment( $( ".comment_tab textarea" ).val( ) );
                          $( ".comment_tab textarea" ).val( "" );
                        } else {
                          addID( $( ".id_tab input[name='taxon_id']" ).val( ),
                            $( ".id_tab textarea" ).val( ) );
                          $( ".id_tab input[name='taxon_id']" ).val( "" );
                          $( ".id_tab textarea" ).val( "" );
                        }
                      } }
                    >
                      Done
                    </Button>
                  </div>
                </Col>
              </Row>
            </Col>
            <Col xs={5} className="opposite_activity">
              <Row>
                <Col xs={12}>
                  <h4>Community ID</h4>
                  <SplitTaxon taxon={observation.taxon} url={`/taxa/${observation.taxon.id}`} />
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
                  <h4>Top Identifiers</h4>
                </Col>
              </Row>
              <Row>
                <Col xs={12}>
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
            <Col xs={5} className="temporary">
              Research grade progress
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
    </div>
  );
};

App.propTypes = {
  observation: PropTypes.object,
  observationPlaces: PropTypes.array,
  config: PropTypes.object,
  observation_places: PropTypes.object,
  addComment: PropTypes.func,
  deleteComment: PropTypes.func,
  addID: PropTypes.func,
  deleteID: PropTypes.func,
  restoreID: PropTypes.func,
  followUser: PropTypes.func,
  unfollowUser: PropTypes.func,
  subscribe: PropTypes.func
};

export default App;
