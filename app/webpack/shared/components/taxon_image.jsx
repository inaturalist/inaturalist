import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

const TaxonImage = ( { taxon, user, size } ) => {
  let title = "";
  if ( taxon ) {
    if ( taxon.rank && taxon.rank_level > 10 ) {
      title += I18n.t( `ranks.${taxon.rank.toLowerCase( )}`, { defaultValue: taxon.rank } );
    }
    title += ` ${taxon.name}`;
    if ( taxon.preferred_common_name ) {
      if ( user && user.prefers_scientific_name_first ) {
        title = `${title} (${_.trim( taxon.preferred_common_name )})`;
      } else {
        title = `${taxon.preferred_common_name} (${_.trim( title )})`;
      }
    }
  }

  let image;
  if ( taxon && taxon.defaultPhoto ) {
    image = (
      <img
        src={ taxon.defaultPhoto.photoUrl( size ) }
        className="taxon-image"
      /> );
  } else if ( taxon && taxon.iconic_taxon_name ) {
    image = (
      <i className={`taxon-image icon icon-iconic-${taxon.iconic_taxon_name.toLowerCase( )}`} />
    );
  }
  image = image || ( <i className="taxon-image icon icon-iconic-unknown" /> );
  return (
    <a
      className="taxonimage TaxonImage"
      href={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}
      title={ title }
    >
      { image }
    </a>
  );
};

TaxonImage.propTypes = {
  taxon: PropTypes.object,
  user: PropTypes.object,
  size: PropTypes.string
};

export default TaxonImage;
