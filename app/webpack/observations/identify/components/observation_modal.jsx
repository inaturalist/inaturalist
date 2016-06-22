import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import {
  Modal,
  Grid,
  Row,
  Col,
  Button,
  Input,
  OverlayTrigger,
  Popover,
  Tooltip
} from "react-bootstrap";
import _ from "lodash";
import moment from "moment";
import DiscussionListContainer from "../containers/discussion_list_container";
import CommentFormContainer from "../containers/comment_form_container";
import IdentificationFormContainer from "../containers/identification_form_container";
import SplitTaxon from "./split_taxon";
import TaxonMap from "./taxon_map";
import UserText from "./user_text";
import ZoomableImageGallery from "./zoomable_image_gallery";

const ObservationModal = ( {
  onClose,
  observation,
  visible,
  toggleReviewed,
  toggleCaptive,
  reviewedByCurrentUser,
  captiveByCurrentUser,
  images,
  commentFormVisible,
  identificationFormVisible,
  addIdentification,
  addComment,
  loadingDiscussionItem,
  agreeWithCurrentObservation,
  currentUserIdentification,
  showNextObservation,
  showPrevObservation
} ) => {
  if ( !observation ) {
    return <div></div>;
  }

  // skipping map until we can work out the memory issues
  let taxonMap;
  const includeMap = true;
  if ( includeMap ) {
    const obsForMap = Object.assign( {}, observation, {
      coordinates_obscured: observation.obscured
    } );
    taxonMap = (
      <TaxonMap
        key={`map-for-${obsForMap.id}`}
        taxonLayers={[{
          taxon: obsForMap.taxon,
          observations: { observation_id: obsForMap.id },
          places: { disabled: true },
          gbif: { disabled: true }
        }] }
        observations={[obsForMap]}
        zoomLevel={ obsForMap.map_scale || 8 }
        mapTypeControl={false}
        showAccuracy
        disableFullscreen
        showAllLayer={false}
        overlayMenu={false}
      />
    );
  }

  let photos = null;
  if ( images && images.length > 0 ) {
    photos = (
      <ZoomableImageGallery
        key={`map-for-${observation.id}`}
        items={images}
        showThumbnails={images && images.length > 1}
        lazyLoad={false}
        server
        showNav={false}
      />
    );
  }
  let sounds = null;
  if ( observation.sounds && observation.sounds.length > 0 ) {
    sounds = observation.sounds.map( s => (
      <iframe
        width="100%"
        height="100"
        scrolling="no"
        frameBorder="no"
        src={`https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/${s.native_sound_id}&auto_play=false&hide_related=false&show_comments=false&show_user=false&show_reposts=false&visual=false&show_artwork=false`}
      ></iframe>
    ) );
  }

  const scrollSidebarToForm = ( form ) => {
    const sidebar = $( form ).parents( ".ObservationModal:first" ).find( ".sidebar" );
    const target = $( form );
    $( ":input:visible:first", form ).focus( );
    $( sidebar ).scrollTo( target );
  };

  const showAgree = ( ) => {
    if ( !currentUserIdentification ) {
      return typeof( observation.taxon ) === "object";
    }
    return ( observation.taxon && observation.taxon.id !== currentUserIdentification.taxon.id );
  };

  const qualityGrade = ( ) => {
    if ( observation.quality_grade === "research" ) {
      return _.capitalize( I18n.t( "research_grade" ) );
    }
    return _.capitalize( I18n.t( observation.quality_grade ) );
  };

  return (
    <Modal
      show={visible}
      onHide={onClose}
      bsSize="large"
      className="ObservationModal"
    >
      <Button className="nav-button" onClick={ function ( ) { showPrevObservation( ); } }>
        &lsaquo;
      </Button>
      <Button className="next nav-button" onClick={ function ( ) { showNextObservation( ); } }>
        &rsaquo;
      </Button>
      <Modal.Header closeButton>
        <Modal.Title>
          <SplitTaxon
            taxon={observation.taxon}
            url={`/observations/${observation.id}`}
            placeholder={observation.species_guess}
          />
          <span className="titlebit">
            <label>{ I18n.t( "observed" ) }:</label>
            { moment( observation.observed_on ).format( "L" ) }
          </span>
          <span className="titlebit">
            <label>{ I18n.t( "by" ) }:</label>
            { observation.user.login }
          </span>
          <span className={`pull-right quality_grade ${observation.quality_grade}`}>
            { qualityGrade( ) }
          </span>
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <Grid fluid>
          <Row>
            <Col xs={8} className={( photos && sounds ) ? "photos sounds" : "media"}>
              { photos }
              { sounds }
            </Col>
            <Col xs={4} className="sidebar">
              { taxonMap }
              <div className="place-guess">
                { observation.place_guess }
              </div>
              <UserText text={observation.description} truncate={100} className="stacked" />
              <DiscussionListContainer observation={observation} />
              <center className={loadingDiscussionItem ? "loading" : "loading collapse"}>
                <i className="fa fa-spin fa-refresh"></i>
              </center>
              <CommentFormContainer
                observation={observation}
                className={commentFormVisible ? "" : "collapse"}
                ref={ function ( elt ) {
                  const domNode = ReactDOM.findDOMNode( elt );
                  if ( domNode && commentFormVisible ) {
                    scrollSidebarToForm( domNode );
                    if (
                      $( "textarea", domNode ).val() === ""
                      && $( ".IdentificationForm textarea" ).val() !== ""
                    ) {
                      $( "textarea", domNode ).val( $( ".IdentificationForm textarea" ).val( ) );
                    }
                  }
                } }
              />
              <IdentificationFormContainer
                observation={observation}
                className={identificationFormVisible ? "" : "collapse"}
                ref={ function ( elt ) {
                  const domNode = ReactDOM.findDOMNode( elt );
                  if ( domNode && identificationFormVisible ) {
                    scrollSidebarToForm( domNode );
                    if (
                      $( "textarea", domNode ).val() === ""
                      && $( ".CommentForm textarea" ).val() !== ""
                    ) {
                      $( "textarea", domNode ).val( $( ".CommentForm textarea" ).val( ) );
                    }
                  }
                } }
              />
            </Col>
          </Row>
        </Grid>
      </Modal.Body>
      <Modal.Footer>
        <Grid fluid>
          <Row>
            <Col xs={4} className="secondary-actions">
              <OverlayTrigger
                trigger="hover"
                placement="top"
                overlay={
                  <Popover title={ I18n.t( "keyboard_shortcuts" ) } id="keyboard-shortcuts-popover">
                    <dl className="keyboard-shortcuts">
                      <dt>z</dt>
                      <dd>{ I18n.t( "organism_appears_captive_cultivated" ) }</dd>
                    </dl>
                    <dl className="keyboard-shortcuts">
                      <dt>r</dt>
                      <dd>{ I18n.t( "mark_as_reviewed" ) }</dd>
                    </dl>
                    <dl className="keyboard-shortcuts">
                      <dt>c</dt>
                      <dd>{ _.capitalize( I18n.t( "comment" ) ) }</dd>
                    </dl>
                    <dl className="keyboard-shortcuts">
                      <dt>a</dt>
                      <dd>{ _.capitalize( I18n.t( "agree" ) ) }</dd>
                    </dl>
                    <dl className="keyboard-shortcuts">
                      <dt>i</dt>
                      <dd>{ I18n.t( "add_id" ) }</dd>
                    </dl>
                    <dl className="keyboard-shortcuts">
                      <dt>&larr;</dt>
                      <dd>{ I18n.t( "previous" ) }</dd>
                    </dl>
                    <dl className="keyboard-shortcuts">
                      <dt>&rarr;</dt>
                      <dd>{ I18n.t( "next" ) }</dd>
                    </dl>
                  </Popover>
                }
              >
                <Button>
                  <i className="fa fa-keyboard-o"></i>
                </Button>
              </OverlayTrigger>
              <OverlayTrigger
                placement="top"
                overlay={
                  <Tooltip id="link-btn-tooltip">
                    { I18n.t( "view_observation" ) }
                  </Tooltip>
                }
                container={ $( "#wrapper.bootstrap" ).get( 0 ) }
              >
                <Button
                  href={`/observations/${observation.id}`}
                  target="_blank"
                >
                  <i className="fa fa-link"></i>
                </Button>
              </OverlayTrigger>
              <OverlayTrigger
                placement="top"
                trigger="hover"
                overlay={
                  <Tooltip id="captive-btn-tooltip">
                    { I18n.t( "organism_appears_captive_cultivated" ) }
                  </Tooltip>
                }
                container={ $( "#wrapper.bootstrap" ).get( 0 ) }
              >
                <div className="captive-checkbox-wrapper">
                  <Input
                    type="checkbox"
                    label={ I18n.t( "captive_cultivated" ) }
                    checked={ captiveByCurrentUser }
                    onChange={function ( ) {
                      toggleCaptive( );
                    }}
                    groupClassName="btn-checkbox"
                  />
                </div>
              </OverlayTrigger>
            </Col>
            <Col xs={8}>
              <OverlayTrigger
                placement="top"
                overlay={
                  <Tooltip id={`modal-reviewed-tooltip-${observation.id}`}>
                    { I18n.t( "mark_as_reviewed" ) }
                  </Tooltip>
                }
                container={ $( "#wrapper.bootstrap" ).get( 0 ) }
              >
                <label
                  className={
                    `btn btn-default btn-checkbox ${( observation.reviewedByCurrentUser || reviewedByCurrentUser ) ? "checked" : ""}`
                  }
                >
                  <input
                    type="checkbox"
                    checked={ observation.reviewedByCurrentUser || reviewedByCurrentUser }
                    onChange={function ( ) {
                      toggleReviewed( );
                    }}
                  /> { I18n.t( "reviewed" ) }
                </label>
              </OverlayTrigger>
              <Button bsStyle="default" onClick={ function ( ) { addComment( ); } }>
                <i className="fa fa-comment"></i> { _.capitalize( I18n.t( "comment" ) ) }
              </Button>
              <OverlayTrigger
                placement="top"
                overlay={
                  <Tooltip id={`modal-agree-tooltip-${observation.id}`}>
                    { I18n.t( "agree_with_current_taxon" ) }
                  </Tooltip>
                }
                container={ $( "#wrapper.bootstrap" ).get( 0 ) }
              >
                <Button
                  bsStyle="default"
                  disabled={ !showAgree( ) }
                  onClick={ function ( ) {
                    agreeWithCurrentObservation( );
                  } }
                >
                  <i className="fa fa-check"></i> { _.capitalize( I18n.t( "agree" ) ) }
                </Button>
              </OverlayTrigger>
              <Button bsStyle="primary" onClick={ function ( ) { addIdentification( ); } } >
                <i className="icon-identification"></i> { I18n.t( "add_id" ) }
              </Button>
            </Col>
          </Row>
        </Grid>
      </Modal.Footer>
    </Modal>
  );
};

ObservationModal.propTypes = {
  onClose: PropTypes.func.isRequired,
  observation: PropTypes.object,
  visible: PropTypes.bool,
  toggleReviewed: PropTypes.func,
  toggleCaptive: PropTypes.func,
  reviewedByCurrentUser: PropTypes.bool,
  captiveByCurrentUser: PropTypes.bool,
  images: PropTypes.array,
  commentFormVisible: PropTypes.bool,
  identificationFormVisible: PropTypes.bool,
  addIdentification: PropTypes.func,
  addComment: PropTypes.func,
  loadingDiscussionItem: PropTypes.bool,
  agreeWithCurrentObservation: PropTypes.func,
  currentUserIdentification: PropTypes.object,
  showNextObservation: PropTypes.func,
  showPrevObservation: PropTypes.func
};

export default ObservationModal;
