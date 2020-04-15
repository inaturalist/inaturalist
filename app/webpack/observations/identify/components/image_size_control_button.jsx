import React from "react";
import PropTypes from "prop-types";

const ImageSizeControlButton = ( { imageSize, setImageSize } ) => (
  <div className="ImageSizeControlButton btn-group" role="group" aria-label={I18n.t( "image_size_control" )}>
    <button
      type="button"
      className={`btn btn-default ${imageSize !== "large" && "active"}`}
      onClick={( ) => setImageSize( null )}
      aria-label={I18n.t( "default" )}
      title={I18n.t( "default" )}
    >
      <i className="fa fa-th" />
    </button>
    <button
      type="button"
      className={`btn btn-default ${imageSize === "large" && "active"}`}
      onClick={( ) => setImageSize( "large" )}
      aria-label={I18n.t( "large" )}
      title={I18n.t( "large" )}
    >
      <i className="fa fa-th-large" />
    </button>
  </div>
);

ImageSizeControlButton.propTypes = {
  imageSize: PropTypes.string,
  setImageSize: PropTypes.func
};

export default ImageSizeControlButton;
