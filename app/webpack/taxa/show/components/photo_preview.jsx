import React, { PropTypes } from "react";
import CoverImage from "./cover_image";

class PhotoPreview extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      photos: []
    };
  }

  componentWillReceiveProps( newProps ) {
    let photos;
    if ( newProps.layout === "gallery" ) {
      photos = newProps.photos.length === 1 ? [] : newProps.photos.slice( 0, 5 );
    } else {
      photos = newProps.photos.slice( 0, 9 );
    }
    this.state = {
      current: newProps.photos[0],
      photos
    };
  }

  showPhoto( photoId ) {
    this.setState( {
      current: this.state.photos.find( p => p.id === photoId )
    } );
  }

  render( ) {
    const layout = this.props.layout;
    const height = layout === "gallery" ? 98 : 185;
    let currentPhoto;
    if ( this.state.current && layout === "gallery" ) {
      currentPhoto = (
        <CoverImage
          src={this.state.current.photoUrl( "large" )}
          low={this.state.current.photoUrl( "small" )}
          height={550}
        />
      );
    }
    return (
      <div className={`PhotoPreview ${layout}`}>
        { currentPhoto }
        <ul className="plain others">
          { this.state.photos.map( p => (
            <li key={ `taxon-photo-${p.id}` }>
              <a
                href=""
                onClick={ e => {
                  e.preventDefault( );
                  this.showPhoto( p.id );
                  return false;
                } }
              >
                <CoverImage
                  src={ layout === "gallery" ? p.photoUrl( "small" ) : p.photoUrl( "small" ) }
                  low={ layout === "gallery" ? p.photoUrl( "small" ) : p.photoUrl( "medium" ) }
                  height={height}
                />
              </a>
            </li>
          ) ) }
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
  photos: PropTypes.array,
  layout: PropTypes.string
};

PhotoPreview.defaultProps = { layout: "gallery" };

export default PhotoPreview;
