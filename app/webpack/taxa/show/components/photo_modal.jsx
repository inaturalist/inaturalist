import React, { PropTypes } from "react";
import { Modal, Button, Grid, Row, Col } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../util";

const PhotoModal = ( {
  photo,
  taxon,
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
  if ( photo ) {
    photoContent = (
      <div
        className="photo-container"
        style={{
          height: "100%",
          backgroundSize: "contain",
          backgroundPosition: "center",
          backgroundImage: `url(${photo.photoUrl( "large" )})`,
          backgroundRepeat: "no-repeat"
        }}
      ></div>
    );
  }
  let taxonContent;
  if ( taxon ) {
    taxonContent = (
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
              className="btn btn-primary text-center pull-right"
            >
              <i className="fa fa-picture-o"></i> { I18n.t( "more_photos_of_this_species" ) }
            </a>
            <SplitTaxon taxon={taxon} url={urlForTaxon( taxon )} />
            <a href={urlForTaxon( taxon )}>
              <i className="fa fa-info-circle"></i> { I18n.t( "about" ) }
            </a>
          </Col>
        </Row>
      </Grid>
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
        { taxonContent }
      </div>
    </Modal>
  );
};

PhotoModal.propTypes = {
  photo: PropTypes.object,
  taxon: PropTypes.object,
  visible: PropTypes.bool,
  onClose: PropTypes.func,
  showNext: PropTypes.func,
  showPrev: PropTypes.func
};

export default PhotoModal;
