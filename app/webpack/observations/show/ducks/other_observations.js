import _ from "lodash";
import inatjs from "inaturalistjs";
import moment from "moment";

const SET_EARLIER_USER_OBSERVATIONS = "obs-show/other_observations/SET_EARLIER_USER_OBSERVATIONS";
const SET_LATER_USER_OBSERVATIONS = "obs-show/other_observations/SET_LATER_USER_OBSERVATIONS";
const SET_EARLIER_USER_OBSERVATIONS_BY_OBSERVED = "obs-show/other_observations/SET_EARLIER_USER_OBSERVATIONS_BY_OBSERVED";
const SET_LATER_USER_OBSERVATIONS_BY_OBSERVED = "obs-show/other_observations/SET_LATER_USER_OBSERVATIONS_BY_OBSERVED";
const SET_NEARBY = "obs-show/other_observations/SET_NEARBY";
const SET_MORE_FROM_CLADE = "obs-show/other_observations/SET_MORE_FROM_CLADE";

const OTHER_OBSERVATIONS_DEFAULT_STATE = {
  earlierUserObservations: [],
  laterUserObservations: [],
  nearby: { },
  moreFromClade: { }
};

const OTHER_OBSERVATION_FIELDS = {
  id: true,
  latitude: true,
  obscured: true,
  photos: {
    id: true,
    uuid: true,
    url: true,
    license_code: true
  },
  taxon: {
    default_photo: {
      attribution: true,
      license_code: true,
      url: true
    },
    id: true,
    is_active: true,
    name: true,
    preferred_common_name: true,
    rank: true,
    rank_level: true
  },
  user: {
    login: true
  },
  uuid: true
};

export default function reducer( state = OTHER_OBSERVATIONS_DEFAULT_STATE, action ) {
  if ( action.data && action.data.params && action.data.params.fields ) {
    delete action.data.params.fields;
  }
  const otherObsFilter = o => (
    !o.obscured
    || o.private_geojson
  );
  switch ( action.type ) {
    case SET_EARLIER_USER_OBSERVATIONS:
      return Object.assign( { }, state, {
        earlierUserObservations: _.filter( action.observations, otherObsFilter )
      } );
    case SET_LATER_USER_OBSERVATIONS:
      return Object.assign( { }, state, {
        laterUserObservations: _.filter( action.observations, otherObsFilter )
      } );
    case SET_EARLIER_USER_OBSERVATIONS_BY_OBSERVED:
      return Object.assign( { }, state, {
        earlierUserObservationsByObserved: action.observations
      } );
    case SET_LATER_USER_OBSERVATIONS_BY_OBSERVED:
      return Object.assign( { }, state, {
        laterUserObservationsByObserved: action.observations
      } );
    case SET_NEARBY:
      return Object.assign( { }, state, {
        nearby: Object.assign( {}, action.data, {
          observations: _.filter( action.data.observations, otherObsFilter )
        } )
      } );
    case SET_MORE_FROM_CLADE:
      return Object.assign( { }, state, {
        moreFromClade: Object.assign( {}, action.data, {
          observations: _.filter( action.data.observations, otherObsFilter )
        } )
      } );
    default:
      // nothing to see here
  }
  return state;
}

export function setEarlierUserObservations( observations ) {
  return {
    type: SET_EARLIER_USER_OBSERVATIONS,
    observations
  };
}

export function setLaterUserObservations( observations ) {
  return {
    type: SET_LATER_USER_OBSERVATIONS,
    observations
  };
}

export function setEarlierUserObservationsByObserved( observations ) {
  return {
    type: SET_EARLIER_USER_OBSERVATIONS_BY_OBSERVED,
    observations
  };
}

export function setLaterUserObservationsByObserved( observations ) {
  return {
    type: SET_LATER_USER_OBSERVATIONS_BY_OBSERVED,
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
    const s = getState( );
    const { testingApiV2 } = s.config;
    const { observation } = s;
    if ( !observation || !observation.geojson ) { return null; }
    const baseParams = {
      lat: observation.geojson.coordinates[1],
      lng: observation.geojson.coordinates[0],
      verifiable: true,
      radius: 50,
      order_by: "observed_on",
      preferred_place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null,
      locale: I18n.locale,
      ttl: -1
    };
    if ( testingApiV2 ) {
      baseParams.fields = OTHER_OBSERVATION_FIELDS;
    }
    const fetchParams = Object.assign( { }, baseParams, {
      photos: true,
      not_id: observation.uuid,
      per_page: 6,
      no_total_hits: true,
      details: "all"
    } );
    return inatjs.observations.search( fetchParams ).then( response => {
      dispatch( setNearby( { params: baseParams, observations: response.results } ) );
    } ).catch( ( ) => { } );
  };
}

export function fetchMoreFromClade( ) {
  return ( dispatch, getState ) => {
    const { observation, config } = getState( );
    const { testingApiV2 } = config;
    if (
      !observation
      || !observation.geojson
      || !observation.taxon
    ) { return null; }
    let searchTaxon = observation.taxon.id;
    if ( observation.taxon.rank_level <= 10 ) {
      searchTaxon = _.find( observation.taxon.ancestors, a => a.rank === "genus" ) || observation.taxon.id;
    }
    const baseParams = {
      taxon_id: searchTaxon,
      order_by: "votes",
      preferred_place_id: config.preferredPlace ? config.preferredPlace.id : null,
      locale: I18n.locale,
      ttl: -1
    };
    if ( testingApiV2 ) {
      baseParams.fields = OTHER_OBSERVATION_FIELDS;
    }
    const fetchParams = Object.assign( { }, baseParams, {
      photos: true,
      not_id: observation.uuid,
      per_page: 6,
      no_total_hits: true,
      details: "all"
    } );
    return inatjs.observations.search( fetchParams ).then( response => {
      dispatch( setMoreFromClade( { params: baseParams, observations: response.results } ) );
    } ).catch( ( ) => { } );
  };
}

export function fetchMoreFromThisUser( ) {
  return async ( dispatch, getState ) => {
    const s = getState( );
    const { testingApiV2, currentUser } = s.config;
    const { observation } = s;
    if ( !observation || !observation.user ) { return null; }
    const baseParams = {
      user_id: observation.user.id,
      order_by: "id",
      per_page: 6,
      no_total_hits: true,
      details: "all",
      preferred_place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null,
      locale: I18n.locale,
      ttl: -1
    };
    if ( testingApiV2 ) {
      baseParams.fields = OTHER_OBSERVATION_FIELDS;
    }
    const prevParams = Object.assign( {}, baseParams, { order: "desc", id_below: observation.id } );
    const nextParams = Object.assign( {}, baseParams, { order: "asc", id_above: observation.id } );
    const responseBefore = await inatjs.observations.search( prevParams );
    const responseAfter = await inatjs.observations.search( nextParams );
    dispatch( setEarlierUserObservations( responseBefore.results ) );
    dispatch( setLaterUserObservations( responseAfter.results ) );

    // Fetch observations for missing location interpolation

    // If we have a location we don't need to interpolate
    if ( observation.latitude || observation.obscured ) return Promise.resolve();
    // If the viewer isn't the observer we shouldn't interpolate
    if ( !currentUser || currentUser.id !== observation.user.id ) return Promise.resolve();
    const obsDateTime = moment( observation.time_observed_at || observation.observed_on );
    // If we don't have a date/time we can't interpolate
    if ( !obsDateTime ) return Promise.resolve();

    const prevByObservedParams = Object.assign( {}, baseParams, {
      order: "desc",
      d1: moment( observation.time_observed_at || observation.observed_on ).subtract( 1, "days" ).format( ),
      d2: obsDateTime.format(),
      geo: true,
      per_page: 1,
      not_id: observation.id
    } );
    const responseObservedBefore = await inatjs.observations.search( prevByObservedParams );

    const nextByObservedParams = Object.assign( {}, baseParams, {
      order: "asc",
      d1: obsDateTime.format(),
      d2: moment( observation.time_observed_at || observation.observed_on ).add( 1, "days" ).format( ),
      has_geo: true,
      per_page: 1,
      not_id: observation.id
    } );
    const responseObservedAfter = await inatjs.observations.search( nextByObservedParams );
    if (
      responseObservedBefore.results.length === 0
      || responseObservedBefore.results.length === 0
    ) {
      return Promise.resolve();
    }
    dispatch( setEarlierUserObservationsByObserved( responseObservedBefore.results ) );
    return dispatch( setLaterUserObservationsByObserved( responseObservedAfter.results ) );
  };
}
