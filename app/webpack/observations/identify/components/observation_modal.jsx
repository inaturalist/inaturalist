import React, { PropTypes } from "react";
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
  images
} ) => {
  if ( !observation ) {
    return <div></div>;
  }

  const scrollSidebarToForm = ( selector, e ) => {

    const sidebar = $( e.target ).parents( ".ObservationModal" )
      .find( ".sidebar" );
    $( "form", sidebar ).hide( );
    const target = $( e.target ).parents( ".ObservationModal" )
      .find( selector );
    $( target ).show( );
    $( sidebar ).scrollTo( target );
  };

  return (
    <Modal show={visible} onHide={onClose} bsSize="large" className="ObservationModal">
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
                items={images}
                showThumbnails={images.length > 1}
              />
            </Col>
            <Col xs={4} className="sidebar">
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
              <DiscussionList observation={observation} />
              <CommentFormContainer observation={observation} className="collapse" />
              <IdentificationFormContainer observation={observation} className="collapse" />
            </Col>
          </Row>
        </Grid>
      </Modal.Body>
      <Modal.Footer>
        <Grid fluid>
          <Row>
            <Col xs={8} className="secondary-actions">
              <Input
                type="checkbox"
                label={ I18n.t( "captive_cultivated" ) }
                checked={ captiveByCurrentUser }
                onChange={function ( e ) {
                  toggleCaptive( observation, e.target.checked );
                }}
                groupClassName="btn-checkbox"
              />
              <Input
                type="checkbox"
                groupClassName="btn-checkbox"
                label={ I18n.t( "reviewed" ) }
                checked={ reviewedByCurrentUser }
                onChange={function ( e ) {
                  toggleReviewed( observation, e.target.checked );
                }}
              />
              <Button
                href={`/observations/${observation.id}`}
                bsStyle="link"
              >
                { I18n.t( "link" ) }
              </Button>
            </Col>
            <Col xs={4}>
              <Button
                onClick={ function ( e ) {scrollSidebarToForm( ".IdentificationForm", e ); } }
              >
                { I18n.t( "add_id" ) }
              </Button>
              <Button onClick={ function ( e ) { scrollSidebarToForm( ".CommentForm", e ); } }>
                { _.capitalize( I18n.t( "comment" ) ) }
              </Button>
              <Button>
                { _.capitalize( I18n.t( "agree" ) ) }
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
  visible: PropTypes.bool.isRequired,
  toggleReviewed: PropTypes.func,
  toggleCaptive: PropTypes.func,
  reviewedByCurrentUser: PropTypes.bool,
  captiveByCurrentUser: PropTypes.bool,
  images: PropTypes.array
};

export default ObservationModal;
