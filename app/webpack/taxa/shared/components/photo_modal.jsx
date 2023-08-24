import React from "react";
import PropTypes from "prop-types";
import {
  Modal,
  Button,
  Grid,
  Row,
  Col
} from "react-bootstrap";
import { bind as bindShortcut, unbind as unbindShortcut } from "mousetrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import {
  urlForTaxon,
  urlForTaxonPhotos,
  localizedPhotoAttribution
} from "../util";

class PhotoModal extends React.Component {
  componentDidMount( ) {
    const { showNext, showPrev } = this.props;
    bindShortcut( "right", ( ) => {
      // using this.props so it will be evaluated at function call time
      if ( this.props.visible ) {
        showNext( );
      }
    } );
    bindShortcut( "left", ( ) => {
      // using this.props so it will be evaluated at function call time
      if ( this.props.visible ) {
        showPrev( );
      }
    } );
  }

  componentWillUnmount( ) {
    unbindShortcut( "right" );
    unbindShortcut( "left" );
  }

  render( ) {
    const {
      photo,
      taxon,
      observation,
      visible,
      onClose,
      showNext,
      showPrev,
      photoLinkUrl,
      linkToTaxon,
      config
    } = this.props;
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
          <span
            dangerouslySetInnerHTML={{
              __html: localizedPhotoAttribution( photo, {
                name: observation ? ( observation.user.name || observation.user.login ) : null
              } )
            }}
          />
          <a href={`/photos/${photo.id}`} title={I18n.t( "details" )}>
            <i className="fa fa-info-circle" />
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
                <SplitTaxon
                  taxon={taxon}
                  url={linkToTaxon ? urlForTaxon( taxon ) : null}
                  user={config.currentUser}
                />
                { linkToTaxon ? (
                  <a href={urlForTaxon( taxon )} className="taxon-link">
                    <i className="fa fa-arrow-circle-right" />
                  </a>
                ) : null }
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
        <button type="button" className="close" onClick={onClose}>×</button>
        <Button className="nav-button" onClick={( ) => showPrev( )}>
          &lsaquo;
        </Button>
        <Button className="next nav-button" onClick={( ) => showNext( )}>
          &rsaquo;
        </Button>
        <div className="photo-modal-content">
          { photoContent }
          { photoAttribution }
          { taxonContent }
        </div>
      </Modal>
    );
  }
}

PhotoModal.propTypes = {
  photo: PropTypes.object,
  taxon: PropTypes.object,
  observation: PropTypes.object,
  visible: PropTypes.bool,
  onClose: PropTypes.func,
  showNext: PropTypes.func,
  showPrev: PropTypes.func,
  photoLinkUrl: PropTypes.string,
  linkToTaxon: PropTypes.bool,
  config: PropTypes.object
};

PhotoModal.defaultProps = {
  config: {},
  linkToTaxon: true
};

export default PhotoModal;
