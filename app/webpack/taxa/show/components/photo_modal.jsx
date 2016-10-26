import React, { PropTypes } from "react";
import { Modal, Button, Grid, Row, Col } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../util";

const PhotoModal = ( {
  photo,
  taxon,
  observation,
  visible,
  onClose,
  showNext,
  showPrev
} ) => {
  let photoContent = (
    <div className="text-center text-muted">
      { I18n.t( "no_photo" ) }
    </div>
  );
  let photoAttribution;
  if ( photo ) {
    let obsLink;
    if ( observation ) {
      obsLink = <a href={`/observations/${observation.id}`}>{ I18n.t( "observation" ) }</a>;
    }
    photoAttribution = (
      <div className="photo-attribution">
        <span>{ photo.attribution }</span>
        <a href={`/photos/${photo.id}`}>{ I18n.t( "details" ) }</a>
        { obsLink }
      </div>
    );
    photoContent = (
      <div
        className="photo-container"
        style={{
          backgroundSize: "contain",
          backgroundPosition: "center",
          backgroundImage: `url(${photo.photoUrl( "large" )})`,
          backgroundRepeat: "no-repeat",
          position: "relative",
          backgroundColor: "black"
        }}
      >
      </div>
    );
  }
  let taxonContent;
  if ( taxon ) {
    taxonContent = (
      <div className="taxon-content">
        <Grid fluid>
          <Row>
            <Col xs={12}>
              <a
                href=""
                onClick={ e => {
                  e.preventDefault( );
                  alert( "TODO" );
                  return false;
                } }
                className="btn btn-link text-center pull-right"
              >
                { I18n.t( "more_photos" ) }
              </a>
              <SplitTaxon taxon={taxon} url={urlForTaxon( taxon )} />
              <a href={urlForTaxon( taxon )} className="taxon-link">
                <i className="fa fa-arrow-circle-right"></i>
              </a>
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
  return (
    <Modal
      show={visible}
      onHide={onClose}
      bsSize="large"
      className="PhotoModal"
    >
      <Button className="nav-button" onClick={ function ( ) { showPrev( ); } }>
        &lsaquo;
      </Button>
      <Button className="next nav-button" onClick={ function ( ) { showNext( ); } }>
        &rsaquo;
      </Button>
      <div className="photo-modal-content">
        { photoContent }
        { photoAttribution }
        { taxonContent }
      </div>
    </Modal>
  );
};

PhotoModal.propTypes = {
  photo: PropTypes.object,
  taxon: PropTypes.object,
  observation: PropTypes.object,
  visible: PropTypes.bool,
  onClose: PropTypes.func,
  showNext: PropTypes.func,
  showPrev: PropTypes.func
};

export default PhotoModal;
