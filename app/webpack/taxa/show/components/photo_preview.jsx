import React from "react";
import PropTypes from "prop-types";
import CoverImage from "../../../shared/components/cover_image";
import { urlForTaxonPhotos } from "../../shared/util";
import TaxonPhoto from "../../shared/components/taxon_photo";

class PhotoPreview extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      taxonPhotos: []
    };
  }

  componentDidMount( ) {
    this.setStateFromProps( this.props );
  }

  componentWillReceiveProps( newProps ) {
    this.setStateFromProps( newProps );
  }

  setStateFromProps( props ) {
    let taxonPhotos;
    if ( props.layout === "gallery" ) {
      taxonPhotos = props.taxonPhotos.slice( 0, 5 );
    } else {
      taxonPhotos = props.taxonPhotos.slice( 0, 8 );
    }
    this.setState( {
      current: props.taxonPhotos[0],
      taxonPhotos
    } );
  }

  showPhoto( photoId ) {
    const { taxonPhotos } = this.state;
    const newTaxonPhoto = taxonPhotos.find( p => p.photo.id === photoId );
    if ( newTaxonPhoto ) {
      this.setState( {
        current: newTaxonPhoto
      } );
    }
  }

  render( ) {
    const {
      layout,
      showTaxonPhotoModal,
      showPhotoChooserModal,
      taxon,
      config,
      showNewTaxon
    } = this.props;
    const {
      taxonPhotos,
      current
    } = this.state;
    const thumbnailHeight = layout === "gallery" ? 98 : 196.5;
    let currentPhoto;
    let bgImage;
    let currentPhotoHeight = 590;
    if ( taxonPhotos.length === 0 ) {
      return (
        <div className="PhotoPreview no-content text-center text-muted">
          <div>
            <h3>
              { I18n.t( "this_taxon_has_no_default_photo" ) }
            </h3>
            <button
              type="button"
              className="btn btn-primary"
              onClick={( ) => showPhotoChooserModal( )}
            >
              { I18n.t( "add_one_now" ) }
            </button>
          </div>
        </div>
      );
    }
    if ( current && layout === "gallery" ) {
      const { photo } = current;
      const dims = photo.dimensions( );
      let ratio = 1;
      if ( dims && dims.height ) {
        ratio = dims.width / dims.height;
      }
      let backgroundSize = "cover";
      if ( ratio > 1.3 ) {
        backgroundSize = "contain";
      }
      if ( backgroundSize === "contain" ) {
        currentPhotoHeight = 500;
        bgImage = (
          <div
            className="photo-bg"
            style={{
              backgroundImage: `url('${current.photo.photoUrl( "small" )}')`
            }}
          />
        );
      }
      currentPhoto = (
        <TaxonPhoto
          taxon={taxon}
          photo={photo}
          size="large"
          showTaxonPhotoModal={showTaxonPhotoModal}
          height={currentPhotoHeight}
          backgroundSize={backgroundSize}
          config={config}
        />
      );
    }
    if ( taxonPhotos.length === 1 ) {
      taxonPhotos.pop( );
    }
    return (
      <div className={`PhotoPreview ${layout}`}>
        { bgImage }
        { currentPhoto }
        <ul className="plain others">
          { taxonPhotos.map( tp => {
            let content;
            if ( layout === "grid" ) {
              content = (
                <TaxonPhoto
                  photo={tp.photo}
                  height={thumbnailHeight}
                  taxon={tp.taxon}
                  showTaxonPhotoModal={showTaxonPhotoModal}
                  className="photoItem"
                  showTaxon
                  linkTaxon={tp.taxon.id !== taxon.id}
                  onClickTaxon={newTaxon => showNewTaxon( newTaxon )}
                  config={config}
                />
              );
            } else {
              content = (
                <a
                  className="photoItem"
                  href={tp.photo.photoUrl()}
                  onClick={e => {
                    e.preventDefault( );
                    this.showPhoto( tp.photo.id );
                    return false;
                  }}
                >
                  <CoverImage
                    src={tp.photo.photoUrl( "small" )}
                    low={tp.photo.photoUrl( "small" )}
                    height={thumbnailHeight}
                  />
                </a>
              );
            }
            return (
              <li key={`taxon-photo-${tp.taxon.id}-${tp.photo.id}`}>
                { content }
              </li>
            );
          } ) }
          <li className="viewmore">
            <a
              href={urlForTaxonPhotos( taxon )}
              style={{ height: layout === "grid" ? `${thumbnailHeight}px` : "inherit" }}
            >
              <span className="inner">
                <span>{ I18n.t( "view_more" )}</span>
                <i className="fa fa-arrow-circle-right" />
              </span>
            </a>
          </li>
        </ul>
      </div>
    );
  }
}

PhotoPreview.propTypes = {
  taxon: PropTypes.object,
  taxonPhotos: PropTypes.array,
  layout: PropTypes.string,
  showTaxonPhotoModal: PropTypes.func,
  showPhotoChooserModal: PropTypes.func,
  showNewTaxon: PropTypes.func,
  config: PropTypes.object
};

PhotoPreview.defaultProps = {
  config: {},
  layout: "gallery"
};

export default PhotoPreview;
