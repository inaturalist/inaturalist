import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import {
  Modal,
  Grid,
  Row,
  Col,
  Button,
  Input
} from "react-bootstrap";
import DiscussionList from "./discussion_list";
import CommentFormContainer from "../containers/comment_form_container";
import IdentificationFormContainer from "../containers/identification_form_container";
import SplitTaxon from "./split_taxon";
import TaxonMap from "./taxon_map";
import _ from "lodash";
import ImageGallery from "react-image-gallery";
import moment from "moment";

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
  currentUserIdentification
} ) => {
  if ( !observation ) {
    return <div></div>;
  }

  // skipping map until we can work out the memory issues
  let taxonMap;
  const includeMap = false;
  if ( includeMap ) {
    taxonMap = (
      <TaxonMap
        key={`map-for-${observation.id}`}
        taxonLayers={[{
          taxon: observation.taxon,
          observations: { observation_id: observation.id },
          places: { disabled: true },
          gbif: { disabled: true }
        }] }
        observations={[observation]}
        zoomLevel={ observation.map_scale || 8 }
        mapTypeControl={false}
        zoomControl={false}
        showAccuracy
        className="stacked"
      />
    );
  }

  const scrollSidebarToForm = ( form ) => {
    const sidebar = $( form ).parents( ".ObservationModal:first" ).find( ".sidebar" );
    const target = $( form );
    $( ":input:visible:first", form ).focus( );
    $( sidebar ).scrollTo( target );
  };

  const showAgree = ( ) => {
    if ( !currentUserIdentification ) {
      return observation.taxon;
    }
    return ( observation.taxon && observation.taxon.id !== currentUserIdentification.taxon.id );
  };

  return (
    <Modal
      show={visible}
      onHide={onClose}
      bsSize="large"
      className="ObservationModal"
    >
      <Modal.Header closeButton>
        <Modal.Title>
          <SplitTaxon taxon={observation.taxon} url={`/observations/${observation.id}`} />
          <span>
            <span className="datebit">
              <label>{ I18n.t( "observed" ) }:</label>
              { moment( observation.observed_on ).format( "L" ) }
            </span>
            <span className="datebit">
              <label>{ I18n.t( "updated" ) }:</label>
              { moment( observation.updated_at ).format( "L" ) }
            </span>
          </span>
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <Grid fluid>
          <Row>
            <Col xs={8}>
              <ImageGallery
                key={`map-for-${observation.id}`}
                items={images}
                showThumbnails={images.length > 1}
                lazyLoad={false}
                server
              />
            </Col>
            <Col xs={4} className="sidebar">
              {taxonMap}
              <DiscussionList observation={observation} />
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
            <Col xs={6} className="secondary-actions">
              <Input
                type="checkbox"
                label={ `${I18n.t( "captive_cultivated" )} [z]` }
                checked={ captiveByCurrentUser }
                onChange={function ( ) {
                  toggleCaptive( );
                }}
                groupClassName="btn-checkbox"
              />
              <Input
                type="checkbox"
                groupClassName="btn-checkbox"
                label={ `${I18n.t( "reviewed" )} [r]` }
                checked={ reviewedByCurrentUser }
                onChange={function ( ) {
                  toggleReviewed( );
                }}
              />
              <Button
                href={`/observations/${observation.id}`}
                bsStyle="link"
              >
                { I18n.t( "link" ) }
              </Button>
            </Col>
            <Col xs={6}>
              <Button onClick={ function ( ) { addIdentification( ); } } >
                { I18n.t( "add_id" ) }
                &nbsp;
                [i]
              </Button>
              <Button onClick={ function ( ) { addComment( ); } }>
                { _.capitalize( I18n.t( "comment" ) ) }
                &nbsp;
                [c]
              </Button>
              <Button
                className={ showAgree( ) ? "" : "collapse"}
                onClick={ function ( ) {
                  agreeWithCurrentObservation( );
                } }
              >
                { _.capitalize( I18n.t( "agree" ) ) }
                &nbsp;
                [a]
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
  currentUserIdentification: PropTypes.object
};

export default ObservationModal;
