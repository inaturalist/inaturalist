import React, { PropTypes } from "react";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserImage from "../../../shared/components/user_image";

const Observation = ( {
  observation,
  width,
  height,
  className,
  size,
  backgroundSize,
  config
} ) => {
  let caption = (
    <div className="caption">
      <SplitTaxon
        taxon={ observation.taxon }
        noParens
        user={ config.currentUser }
        url={ `/observations/${observation.id}` }
      />
      <UserImage user={ observation.user } />
    </div>
  );
  const style = { width, maxWidth: 2 * width };
  let img;
  if ( observation.photos.length > 0 ) {
    const photo = observation.photos[0];
    img = (
      <CoverImage
        src={ photo.photoUrl( size ) || photo.photoUrl( "small" ) }
        low={ photo.photoUrl( "small" ) }
        height={ height }
        backgroundSize={ backgroundSize }
      />
    );
  } else {
    const iconicTaxonClass = observation.taxon && observation.taxon.iconic_taxon_name ?
      observation.taxon.iconic_taxon_name.toLowerCase( ) : "unknown";
    img = (
      <div className="photo" style={{ height, lineHeight: `${height}px` }}>
        <i className={ `icon-iconic-${iconicTaxonClass}`} />
      </div>
    );
  }
  return (
    <div
      className={`ObservationPhoto ${className}`}
      style={ style }
      key={ `observation-photo-${observation.id}` }
    >
      <a href={ `/observations/${observation.id}` }>
        { img }
      </a>
      { caption }
    </div>
  );
};

Observation.propTypes = {
  observation: PropTypes.object.isRequired,
  width: PropTypes.number,
  height: PropTypes.number.isRequired,
  className: PropTypes.string,
  size: PropTypes.string,
  backgroundSize: PropTypes.string,
  showTaxon: PropTypes.bool,
  linkTaxon: PropTypes.bool,
  onClickTaxon: PropTypes.func,
  photoKey: PropTypes.string,
  config: PropTypes.object
};

Observation.defaultProps = {
  size: "medium",
  config: {}
};

export default Observation;
