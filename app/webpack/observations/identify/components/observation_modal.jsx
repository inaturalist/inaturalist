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
import SuggestionsContainer from "../containers/suggestions_container";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonMap from "./taxon_map";
import UserText from "../../../shared/components/user_text";
import ZoomableImageGallery from "./zoomable_image_gallery";

class ObservationModal extends React.Component {
  // constructor( props ) {
  //   super( props );
  //   this.state = {
  //     tab: "info",
  //     loaded: {}
  //   };
  // }
  // chooseTab( tab ) {
  //   this.setState( { tab } );
  // }
  // loadSuggestions( options = {} ) {
  //   if ( tab === "suggestions" && ( options.force || !this.state.loaded.suggestions ) ) {
  //     this.props.fetchSuggestions( { observation_id: this.props.observation.id } );
  //     this.setState( { loaded: { suggestions: true } } );
  //   }
  // }
  render( ) {
    const {
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
      showPrevObservation,
      agreeingWithObservation,
      blind,
      tab,
      chooseTab
    } = this.props;
    if ( !observation ) {
      return <div></div>;
    }

    // skipping map until we can work out the memory issues
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
      const taxonLayer = {
        observations: { observation_id: obsForMap.id },
        places: { disabled: true }
      };
      if ( !blind ) {
        taxonLayer.taxon = obsForMap.taxon;
        taxonLayer.gbif = { disabled: true };
      }
      taxonMap = (
        <TaxonMap
          key={`map-for-${obsForMap.id}`}
          taxonLayers={ [taxonLayer] }
          observations={[obsForMap]}
          clickable={!blind}
          zoomLevel={ observation.map_scale || 8 }
          mapTypeControl={false}
          showAccuracy
          showAllLayer={false}
          overlayMenu={false}
          zoomControlOptions={{ position: google.maps.ControlPosition.TOP_LEFT }}
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
      if ( loadingDiscussionItem ) {
        return false;
      }
      if ( !currentUserIdentification ) {
        return observation.taxon && observation.taxon.is_active;
      }
      return (
        observation.taxon &&
        observation.taxon.is_active &&
        observation.taxon.id !== currentUserIdentification.taxon.id
      );
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
        className={`ObservationModal ${blind ? "blind" : ""}`}
      >
        <Modal.Header closeButton>
          <Modal.Title>
            <SplitTaxon
              taxon={observation.taxon}
              url={`/observations/${observation.id}`}
              placeholder={observation.species_guess}
            /> <span className={`quality_grade ${observation.quality_grade}`}>
              { qualityGrade( ) }
            </span>
          </Modal.Title>
          <ul className="inat-tabs">
            {["info", "annotations", "data-quality", "suggestions"].map( tabName => (
              <li className={tab === tabName ? "active" : ""}>
                <a
                  href="#"
                  onClick={ e => {
                    e.preventDefault( );
                    chooseTab( tabName );
                    return false;
                  } }
                >
                  { I18n.t( tabName, { defaultValue: tabName } ) }
                </a>
              </li>
            ) ) }
          </ul>
        </Modal.Header>
        <Modal.Body>
          <div className={( photos && sounds ) ? "photos sounds" : "media"}>
            <div className="column-header">{ I18n.t( "detail" ) }</div>
            { photos }
            { sounds }
          </div>
          <div className="sidebar">
            <div className={`inat-tab info-tab ${tab === "info" ? "active" : ""}`}>
              <div className="map-and-details">
                { taxonMap }
                <ul className="details">
                  <li>
                    <i className="icon-person"></i> { observation.user.login }
                  </li>
                  <li>
                    <i className="fa fa-map-marker"></i> { observation.place_guess }
                  </li>
                  <li>
                    <i className="fa fa-calendar"></i> { moment( observation.observed_on ).format( "L" ) }
                  </li>
                  <li>
                    <a className="permalink" href={`/observations/${observation.id}`}>
                      <i className="icon-link"></i>
                      { I18n.t( "view_observation" ) }
                    </a>
                  </li>
                </ul>
              </div>
              <div className="place-guess">
                { observation.place_guess }
              </div>
              <UserText text={observation.description} truncate={100} className="stacked observation-description" />
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
            </div>
            <div className={`inat-tab annotations-tab ${tab === "annotations" ? "active" : ""}`}>
              annotations
            </div>
            <div className={`inat-tab data-quality-tab ${tab === "data-quality" ? "active" : ""}`}>
              data-quality
            </div>
            <div className={`inat-tab suggestions-tab ${tab === "suggestions" ? "active" : ""}`}>
              <SuggestionsContainer />
            </div>
          </div>
          <Button className="nav-button" onClick={ function ( ) { showPrevObservation( ); } }>
            &lsaquo;
          </Button>
          <Button className="next nav-button" onClick={ function ( ) { showNextObservation( ); } }>
            &rsaquo;
          </Button>
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
                      { blind ? null : (
                        <dl className="keyboard-shortcuts">
                          <dt>c</dt>
                          <dd>{ _.capitalize( I18n.t( "comment" ) ) }</dd>
                        </dl>
                      ) }
                      { blind ? null : (
                        <dl className="keyboard-shortcuts">
                          <dt>a</dt>
                          <dd>{ _.capitalize( I18n.t( "agree" ) ) }</dd>
                        </dl>
                      ) }
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
                  delayShow={1000}
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
                    className="link-btn"
                  >
                    <i className="fa fa-link"></i>
                  </Button>
                </OverlayTrigger>
                <OverlayTrigger
                  placement="top"
                  trigger="hover"
                  delayShow={1000}
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
                  delayShow={1000}
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
                <Button
                  bsStyle="default"
                  className="comment-btn"
                  onClick={ function ( ) { addComment( ); } }
                >
                  <i className="fa fa-comment"></i> { _.capitalize( I18n.t( "comment" ) ) }
                </Button>
                <OverlayTrigger
                  placement="top"
                  delayShow={1000}
                  overlay={
                    <Tooltip id={`modal-agree-tooltip-${observation.id}`}>
                      { I18n.t( "agree_with_current_taxon" ) }
                    </Tooltip>
                  }
                  container={ $( "#wrapper.bootstrap" ).get( 0 ) }
                >
                  <Button
                    bsStyle="default"
                    disabled={ agreeingWithObservation || !showAgree( ) }
                    className="agree-btn"
                    onClick={ function ( ) {
                      agreeWithCurrentObservation( );
                    } }
                  >
                    <i className={ agreeingWithObservation ? "fa fa-refresh fa-spin fa-fw" : "fa fa-check" }>
                    </i> { _.capitalize( I18n.t( "agree" ) ) }
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
  }
}

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
  showPrevObservation: PropTypes.func,
  agreeingWithObservation: PropTypes.bool,
  blind: PropTypes.bool,
  tab: PropTypes.bool,
  chooseTab: PropTypes.func
};

export default ObservationModal;
