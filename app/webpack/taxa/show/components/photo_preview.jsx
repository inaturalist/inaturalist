import React, { PropTypes } from "react";

const PhotoPreview = ( { photos } ) => (
  <div className="PhotoPreview">
    { photos.map( p => <img key={ `taxon-photo-${p.id}` } src={ p.square_url } /> ) }
  </div>
);

PhotoPreview.propTypes = {
  photos: PropTypes.array
};

export default PhotoPreview;
