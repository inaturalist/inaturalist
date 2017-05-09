import inatjs from "inaturalistjs";

const SET_MORE_FROM_THIS_USER = "obs-show/other_observations/SET_MORE_FROM_THIS_USER";
const SET_NEARBY = "obs-show/other_observations/SET_NEARBY";
const SET_MORE_FROM_CLADE = "obs-show/other_observations/SET_MORE_FROM_CLADE";

const OTHER_OBSERVATIONS_DEFAULT_STATE = {
  moreFromUser: [],
  nearby: { },
  moreFromClade: { }
};

export default function reducer( state = OTHER_OBSERVATIONS_DEFAULT_STATE, action ) {
  switch ( action.type ) {
    case SET_MORE_FROM_THIS_USER:
      return Object.assign( { }, state, { moreFromUser: action.observations } );
    case SET_NEARBY:
      return Object.assign( { }, state, { nearby: action.data } );
    case SET_MORE_FROM_CLADE:
      return Object.assign( { }, state, { moreFromClade: action.data } );
    default:
      // nothing to see here
  }
  return state;
}

export function setMoreFromThisUser( observations ) {
  return {
    type: SET_MORE_FROM_THIS_USER,
    observations
  };
}

export function setNearby( data ) {
  return {
    type: SET_NEARBY,
    data
  };
}

export function setMoreFromClade( data ) {
  return {
    type: SET_MORE_FROM_CLADE,
    data
  };
}

export function fetchNearby( ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    if ( !observation || !observation.latitude || !observation.longitude ) { return null; }
    const baseParams = { lat: observation.latitude, lng: observation.longitude, radius: 50,
      order_by: "observed_on" };
    const fetchParams = Object.assign( { }, baseParams, {
      photos: true, not_id: observation.id, per_page: 6 } );
    return inatjs.observations.search( fetchParams ).then( response => {
      dispatch( setNearby( { params: baseParams, observations: response.results } ) );
    } ).catch( e => { } );
  };
}

export function fetchMoreFromClade( ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    if ( !observation || !observation.latitude || !observation.longitude ||
         !observation.taxon ) { return null; }
    const searchTaxon =
      observation.taxon.min_species_ancestry.split( "," ).reverse( )[1] || observation.taxon.id;
    const baseParams = { taxon_id: searchTaxon, order_by: "votes" };
    const fetchParams = Object.assign( { }, baseParams, {
      photos: true, not_id: observation.id, per_page: 6 } );
    return inatjs.observations.search( fetchParams ).then( response => {
      dispatch( setMoreFromClade( { params: baseParams, observations: response.results } ) );
    } ).catch( e => { } );
  };
}

export function fetchMoreFromThisUser( ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    if ( !observation || !observation.user ) { return null; }
    // TODO: this needs to be smarter
    let params = { user_id: observation.user.id, order_by: "id",
      order: "desc", id_below: observation.id, per_page: 3 };
    return inatjs.observations.search( params ).then( responseBefore => {
      params = { user_id: observation.user.id, order_by: "id",
        order: "asc", id_above: observation.id, per_page: 3 };
      return inatjs.observations.search( params ).then( responseAfter => {
        dispatch( setMoreFromThisUser( responseBefore.results.concat( responseAfter.results ) ) );
      } ).catch( e => { } );
    } ).catch( e => { } );
  };
}

