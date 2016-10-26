import React, { PropTypes } from "react";
import CoverImage from "./cover_image";
import { urlForTaxon } from "../util";
import SplitTaxon from "../../../shared/components/split_taxon";

class PhotoPreview extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      taxonPhotos: []
    };
  }

  componentWillReceiveProps( newProps ) {
    let taxonPhotos;
    if ( newProps.layout === "gallery" ) {
      taxonPhotos = newProps.taxonPhotos.slice( 0, 5 );
    } else {
      taxonPhotos = newProps.taxonPhotos.slice( 0, 9 );
    }
    this.state = {
      current: newProps.taxonPhotos[0],
      taxonPhotos
    };
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
    const height = layout === "gallery" ? 98 : 185;
    let currentPhoto;
    const showTaxonPhotoModal = this.props.showTaxonPhotoModal;
    if ( this.state.taxonPhotos.length === 0 ) {
      return (
        <div className="text-center text-muted">
          { I18n.t( "no_photos" ) }
        </div>
      );
    }
    if ( this.state.current && layout === "gallery" ) {
      currentPhoto = (
        <CoverImage
          src={this.state.current.photo.photoUrl( "large" )}
          low={this.state.current.photo.photoUrl( "small" )}
          height={550}
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
            const coverImage = (
              <CoverImage
                src={ layout === "gallery" ? tp.photo.photoUrl( "small" ) : tp.photo.photoUrl( "small" ) }
                low={ layout === "gallery" ? tp.photo.photoUrl( "small" ) : tp.photo.photoUrl( "medium" ) }
                height={height}
              />
            );
            let content;
            if ( layout === "grid" ) {
              content = (
                <span className="photoItem">
                  <div className="photo-hover">
                    <div className="actions">
                      <button
                        className="btn btn-link"
                        onClick={ e => {
                          e.preventDefault( );
                          showTaxonPhotoModal( tp );
                          return false;
                        } }
                      >
                        <i className="fa fa-search-plus"></i>
                        { I18n.t( "enlarge" ) }
                      </button>
                      <button
                        className="btn btn-link"
                        onClick={ e => {
                          e.preventDefault( );
                          alert( "TODO" );
                          return false;
                        } }
                      >
                        <i className="fa fa-picture-o"></i>
                        { I18n.t( "view_all" ) }
                      </button>
                    </div>
                    <div className="photo-taxon">
                      <SplitTaxon taxon={tp.taxon} noParens url={urlForTaxon( tp.taxon )} />
                      <a href={urlForTaxon( tp.taxon )} className="btn btn-link">
                        <i className="fa fa-info-circle"></i>
                      </a>
                    </div>
                  </div>
                  { coverImage }
                </span>
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
                  { coverImage }
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
            <a href=""
              onClick={ e => {
                e.preventDefault( );
                alert( "TODO" );
                return false;
              } }
            >
              { I18n.t( "view_more" )} <i className="fa fa-arrow-circle-right"></i>
            </a>
          </li>
        </ul>
      </div>
    );
  }
}

PhotoPreview.propTypes = {
  taxonPhotos: PropTypes.array,
  layout: PropTypes.string,
  showTaxonPhotoModal: PropTypes.func
};

PhotoPreview.defaultProps = { layout: "gallery" };

export default PhotoPreview;
