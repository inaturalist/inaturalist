import _ from "lodash";
import React from "react";

const util = class util {
  static taxaDissimilar( testTaxon, compareToTaxon ) {
    const testTaxonAncestry = _.isEmpty( testTaxon.ancestry )
      ? `${testTaxon.id}`
      : `${testTaxon.ancestry}/${testTaxon.id}`;
    const compareToTaxonAncestry = _.isEmpty( compareToTaxon.ancestry )
      ? compareToTaxon.id
      : `${compareToTaxon.ancestry}/${compareToTaxon.id}`;
    return !(
      ( testTaxonAncestry.id === compareToTaxon.id )
      || ( testTaxonAncestry.includes( compareToTaxonAncestry ) ) );
  }

  static taxonImage( taxon, options = { } ) {
    const stubImage = ( <i className="taxon-image icon icon-iconic-unknown" /> );
    if ( !taxon ) {
      return stubImage;
    }
    const photo = taxon?.representativePhoto || taxon?.defaultPhoto;
    if ( photo ) {
      return (
        <img
          alt={taxon.name}
          src={photo.photoUrl( options.size )}
          className="taxon-image"
        />
      );
    }
    if ( taxon.iconic_taxon_name ) {
      return (
        <i className={`taxon-image icon icon-iconic-${taxon.iconic_taxon_name.toLowerCase( )}`} />
      );
    }
    return stubImage;
  }

  static observationMissingProjectFields( observation, project ) {
    if ( !project || _.isEmpty( project.project_observation_fields ) ) {
      return false;
    }
    const missingFields = [];
    _.each( project.project_observation_fields, pf => {
      if ( !_.find( observation.ofvs, ofv => ofv.observation_field.id === pf.observation_field.id )
      ) {
        missingFields.push( pf );
      }
    } );
    return missingFields;
  }
};

export default util;
