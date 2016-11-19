import isomorphicFetch from "isomorphic-fetch";
import _ from "lodash";

const urlForTaxon = ( t ) => `/taxa/${t.id}-${t.name.split( " " ).join( "-" )}?test=taxon-page`;
const urlForTaxonPhotos = ( t, params ) => {
  let url = `/taxa/${t.id}-${t.name.split( " " ).join( "-" )}/browse_photos`;
  if ( params ) {
    url += `?${_.map( params, ( v, k ) => `${k}=${v}` ).join( "&" )}`;
  }
  return url;
};
const urlForUser = ( u ) => `/people/${u.login}`;

// Light wrapper around isomorphic fetch to ensure credentials are always passed through
const fetch = ( url, options ) =>
  isomorphicFetch( url, Object.assign( {}, options, { credentials: "same-origin" } ) );

const defaultObservationParams = ( state ) => ( {
  verifiable: true,
  taxon_id: state.taxon.taxon ? state.taxon.taxon.id : null,
  place_id: state.config.chosenPlace ? state.config.chosenPlace.id : null
} );

export {
  urlForTaxon,
  urlForTaxonPhotos,
  urlForUser,
  fetch,
  defaultObservationParams
};
