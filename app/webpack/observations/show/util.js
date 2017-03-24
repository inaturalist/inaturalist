import _ from "lodash";
import React from "react";

const util = class util {

  static taxaDissimilar( testTaxon, compareToTaxon ) {
    const testTaxonAncestry = _.isEmpty( testTaxon.ancestry ) ? testTaxon.id :
      `${testTaxon.ancestry}/${testTaxon.id}`;
    const compareToTaxonAncestry = _.isEmpty( compareToTaxon.ancestry ) ? compareToTaxon.id :
      `${compareToTaxon.ancestry}/${compareToTaxon.id}`;
    return !(
      ( testTaxonAncestry.id === compareToTaxon.id ) ||
      ( testTaxonAncestry.includes( compareToTaxonAncestry ) ) );
  }

  static taxonImage( taxon, options = { } ) {
    if ( taxon && taxon.defaultPhoto ) {
      return (
        <img
          src={ taxon.defaultPhoto.photoUrl( options.size ) }
          className="taxon-image"
        /> );
    } else if ( taxon.iconic_taxon_name ) {
      return (
        <i className={`taxon-image icon icon-iconic-${taxon.iconic_taxon_name.toLowerCase( )}`} />
      );
    }
    return ( <i className="taxon-image icon icon-iconic-unknown" /> );
  }

};

export default util;
