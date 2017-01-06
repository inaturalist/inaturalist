import React, { PropTypes } from "react";
import { Modal, Button, Grid, Row, Col } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import {
  urlForTaxon,
  urlForTaxonPhotos,
  localizedPhotoAttribution
} from "../../shared/util";

const PhotoModal = ( {
  photo,
  taxon,
  observation,
  visible,
  onClose,
  showNext,
  showPrev,
  photoLinkUrl
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
      obsLink = <a href={`/observations/${observation.id}`}>{ I18n.t( "view_observation" ) }</a>;
    }
    photoAttribution = (
      <div className="photo-attribution">
        {
          localizedPhotoAttribution( photo, {
            name: observation ? ( observation.user.name || observation.user.login ) : null
          } )
        }
        <a href={`/photos/${photo.id}`} title={ I18n.t( "details" ) }>
          <i className="fa fa-info-circle"></i>
        </a>
        { obsLink }
      </div>
    );
    const PhotoElement = photoLinkUrl ? "a" : "div";
    photoContent = (
      <PhotoElement
        href={photoLinkUrl}
        className="photo-container"
        style={{
          backgroundSize: "contain",
          backgroundPosition: "center",
          backgroundImage: `url('${photo.photoUrl( "large" )}')`,
          backgroundRepeat: "no-repeat",
          position: "relative",
          backgroundColor: "black"
        }}
      />
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
                href={urlForTaxonPhotos( taxon )}
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
  showPrev: PropTypes.func,
  photoLinkUrl: PropTypes.string
};

export default PhotoModal;
