import React, { PropTypes } from "react";

const PhotoPreview = ( { photos } ) => {
  if ( photos.length === 0 ) {
    return <div className="PhotoPreview" />;
  }
  const single = photos[0];
  return (
    <div className="PhotoPreview">
      <img src={single.medium_url} className="img-responsive" />
      <div className="others">
        { photos.map( p => <img key={ `taxon-photo-${p.id}` } src={ p.photoUrl( "square" ) } /> ) }
      </div>
    </div>
  );
};

PhotoPreview.propTypes = {
  photos: PropTypes.array
};

export default PhotoPreview;
