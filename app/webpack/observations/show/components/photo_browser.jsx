import React, { PropTypes } from "react";
import { Badge, OverlayTrigger, Tooltip } from "react-bootstrap";
import ZoomableImageGallery from "../../identify/components/zoomable_image_gallery";


const PhotoBrowser = ( { observation } ) => {
  if ( !observation ) { return ( <div /> ); }
  if ( !observation.photos || observation.photos.length === 0 ) {
    return (
      <div className="PhotoBrowser empty">
        <i className="fa fa-picture-o" />
        No Photo
      </div>
    );
  }
  // TODO: need to get license URLs somewhere; proper abbreviations
  const images = observation.photos.map( ( photo ) => ( {
    original: photo.photoUrl( "large" ),
    zoom: photo.photoUrl( "original" ),
    thumbnail: photo.photoUrl( "square" ),
    description: (
      <div className="captions">
        <OverlayTrigger
          placement="top"
          delayShow={ 500 }
          overlay={ ( <Tooltip id="add-tip">{ photo.attribution }</Tooltip> ) }
          key={ `photo-${photo.id}-license` }
        >
          { photo.license_code ? ( <i className="fa fa-creative-commons license" /> ) :
              ( <i className="fa fa-copyright license" /> ) }
        </OverlayTrigger>
        <a href={ `/photos/${photo.id}` }>
          <Badge>
            <i className="fa fa-info" />
          </Badge>
        </a>
      </div>
    )
  } ) );
  return (
    <div className="PhotoBrowser">
      <ZoomableImageGallery
        key={`map-for-${observation.id}`}
        items={images}
        showThumbnails={images && images.length > 1}
        lazyLoad={false}
        server
        showNav={false}
      />
    </div>
  );
};

PhotoBrowser.propTypes = {
  observation: PropTypes.object
};

export default PhotoBrowser;
