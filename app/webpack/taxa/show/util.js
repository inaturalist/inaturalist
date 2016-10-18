import isomorphicFetch from "isomorphic-fetch";

const urlForTaxon = ( t ) => `/taxa/${t.id}-${t.name.split( " " ).join( "-" )}?test=taxon-page`;
const urlForUser = ( u ) => `/people/${u.login}`;

// Light wrapper around isomorphic fetch to ensure credentials are always passed through
const fetch = ( url, options ) =>
  isomorphicFetch( url, Object.assign( {}, options, { credentials: "same-origin" } ) );

const defaultObservationParams = ( state ) => ( {
  verifiable: true,
  taxon_id: state.taxon.taxon ? state.taxon.taxon.id : null,
  place_id: state.config.preferredPlace ? state.config.preferredPlace.id : null
} );

export {
  urlForTaxon,
  urlForUser,
  fetch,
  defaultObservationParams
};
