import _ from "lodash";
import inatjs from "inaturalistjs";

const SET_EARLIER_USER_OBSERVATIONS = "obs-show/other_observations/SET_EARLIER_USER_OBSERVATIONS";
const SET_LATER_USER_OBSERVATIONS = "obs-show/other_observations/SET_LATER_USER_OBSERVATIONS";
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

const TESTING_INTEPROLATION_MITIGATION = typeof ( CURRENT_USER ) === "object"
  && CURRENT_USER.testGroups
  && CURRENT_USER.testGroups.includes( "interpolation" );

export default function reducer( state = OTHER_OBSERVATIONS_DEFAULT_STATE, action ) {
  if ( action.data && action.data.params && action.data.params.fields ) {
    delete action.data.params.fields;
  }
  const otherObsFilter = o => (
    !TESTING_INTEPROLATION_MITIGATION
    || !o.obscured
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
      skip_total_hits: true,
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
      skip_total_hits: true,
      details: "all"
    } );
    return inatjs.observations.search( fetchParams ).then( response => {
      dispatch( setMoreFromClade( { params: baseParams, observations: response.results } ) );
    } ).catch( ( ) => { } );
  };
}

export function fetchMoreFromThisUser( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { testingApiV2 } = s.config;
    const { observation } = s;
    if ( !observation || !observation.user ) { return null; }
    const baseParams = {
      user_id: observation.user.id,
      order_by: "id",
      per_page: 6,
      skip_total_hits: true,
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
    return inatjs.observations.search( prevParams ).then(
      responseBefore => inatjs.observations.search( nextParams ).then( responseAfter => {
        dispatch( setEarlierUserObservations( responseBefore.results ) );
        dispatch( setLaterUserObservations( responseAfter.results ) );
      } ).catch( ( ) => { } )
    ).catch( ( ) => { } );
  };
}
