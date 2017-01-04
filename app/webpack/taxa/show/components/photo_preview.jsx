import React, { PropTypes } from "react";
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
    const newTaxonPhoto = this.state.taxonPhotos.find( p => p.photo.id === photoId );
    if ( newTaxonPhoto ) {
      this.setState( {
        current: newTaxonPhoto
      } );
    }
  }

  render( ) {
    const layout = this.props.layout;
    const height = layout === "gallery" ? 98 : 196.5;
    let currentPhoto;
    const showTaxonPhotoModal = this.props.showTaxonPhotoModal;
    if ( this.state.taxonPhotos.length === 0 ) {
      return (
        <div className="PhotoPreview no-content text-center text-muted">
          <div>
            <h3>
              { I18n.t( "this_taxon_has_no_default_photo" ) }
            </h3>
            <button
              className="btn btn-primary"
              onClick={ ( ) => this.props.showPhotoChooserModal( ) }
            >
              { I18n.t( "add_one_now" ) }
            </button>
          </div>
        </div>
      );
    }
    if ( this.state.current && layout === "gallery" ) {
      currentPhoto = (
        <TaxonPhoto
          taxon={this.props.taxon}
          photo={this.state.current.photo}
          size="large"
          showTaxonPhotoModal={showTaxonPhotoModal}
          height={590}
        />
      );
    }
    const taxonPhotos = this.state.taxonPhotos;
    if ( taxonPhotos.length === 1 ) {
      taxonPhotos.pop( );
    }
    return (
      <div className={`PhotoPreview ${layout}`}>
        { currentPhoto }
        <ul className="plain others">
          { this.state.taxonPhotos.map( tp => {
            let content;
            if ( layout === "grid" ) {
              content = (
                <TaxonPhoto
                  photo={tp.photo}
                  height={height}
                  taxon={tp.taxon}
                  showTaxonPhotoModal={showTaxonPhotoModal}
                  className="photoItem"
                  showTaxon
                  onClickTaxon={ taxon => this.props.showNewTaxon( taxon ) }
                />
              );
            } else {
              content = (
                <a
                  className="photoItem"
                  href=""
                  onClick={ e => {
                    e.preventDefault( );
                    this.showPhoto( tp.photo.id );
                    return false;
                  } }
                >
                  <CoverImage
                    src={ tp.photo.photoUrl( "small" ) }
                    low={ tp.photo.photoUrl( "small" ) }
                    height={height}
                  />
                </a>
              );
            }
            return (
              <li key={ `taxon-photo-${tp.taxon.id}-${tp.photo.id}` }>
                { content }
              </li>
            );
          } ) }
          <li className="viewmore">
            <a href={urlForTaxonPhotos( this.props.taxon )}
              style={{ height: layout === "grid" ? `${height}px` : "inherit" }}
            >
              <span className="inner">
                <span>{ I18n.t( "view_more" )}</span>
                <i className="fa fa-arrow-circle-right"></i>
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
  showNewTaxon: PropTypes.func
};

PhotoPreview.defaultProps = { layout: "gallery" };

export default PhotoPreview;
