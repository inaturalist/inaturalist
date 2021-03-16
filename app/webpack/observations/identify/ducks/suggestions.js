import inatjs from "inaturalistjs";
import _ from "lodash";

import {
  UPDATE_CURRENT_OBSERVATION
} from "../actions/current_observation_actions";

const RESET = "observations-identify/suggestions/RESET";
const START_LOADING = "observations-identify/suggestions/START_LOADING";
const STOP_LOADING = "observations-identify/suggestions/STOP_LOADING";
const SET_QUERY = "observations-identify/suggestions/SET_QUERY";
const SET_SUGGESTIONS = "observations-identify/suggestions/SET_SUGGESTIONS";
const SET_DETAIL_TAXON = "observations-identify/suggestions/SET_DETAIL_TAXON";
const UPDATE_WITH_OBSERVATION = "observations-identify/suggestions/UPDATE_WITH_OBSERVATION";

const TAXON_FIELDS = {
  ancestor_ids: true,
  id: true,
  name: true,
  rank: true,
  rank_level: true,
  iconic_taxon_name: true,
  is_active: true,
  preferred_common_name: true
};

const PHOTO_FIELDS = {
  attribution: true,
  id: true,
  license_code: true,
  medium_url: true,
  original_dimensions: "all",
  url: true
};

export default function reducer(
  state = {
    query: {
      source: "observations",
      order_by: "default"
    },
    loading: false,
    response: {
      results: []
    },
    responseQuery: null,
    detailTaxon: null,
    detailPhotoIndex: 0,
    observation: null // optional observation from which to derive default values for query
  },
  action
) {
  const newState = Object.assign( {}, state );
  switch ( action.type ) {
    case RESET:
      // Reset suggestions, just use the default state
      break;
    case START_LOADING:
      newState.loading = true;
      newState.response.results = [];
      newState.detailTaxon = null;
      break;
    case STOP_LOADING:
      newState.loading = false;
      break;
    case SET_QUERY:
      newState.query = action.query || {};
      break;
    case SET_SUGGESTIONS:
      newState.response = action.suggestions;
      newState.responseQuery = state.query;
      newState.detailTaxon = null;
      break;
    case SET_DETAIL_TAXON:
      newState.detailTaxon = action.taxon;
      if ( action.options ) {
        newState.detailPhotoIndex = action.options.detailPhotoIndex;
      }
      break;
    case UPDATE_WITH_OBSERVATION: {
      newState.query = {
        source: state.query.source,
        order_by: state.query.order_by
      };
      const { observation } = action;
      if ( observation.taxon ) {
        let indexOfTaxonInAncestors = observation.taxon.ancestor_ids
          .indexOf( observation.taxon.id );
        if ( indexOfTaxonInAncestors < 0 ) {
          indexOfTaxonInAncestors = observation.taxon.ancestor_ids.length;
        }
        if ( observation.taxon.rank_level === 10 ) {
          newState.query.taxon_id = observation
            .taxon.ancestor_ids[Math.max( indexOfTaxonInAncestors - 1, 0 )];
        } else if ( observation.taxon.rank_level < 10 ) {
          newState.query.taxon_id = observation
            .taxon.ancestor_ids[Math.max( indexOfTaxonInAncestors - 2, 0 )];
        } else {
          newState.query.taxon_id = observation.taxon.id;
        }
      }
      let placeIDs;
      if ( observation.private_place_ids && observation.private_place_ids.length > 0 ) {
        placeIDs = observation.private_place_ids;
      } else {
        placeIDs = observation.place_ids;
      }
      if ( observation.places ) {
        const place = _
          .sortBy( observation.places, p => p.bbox_area )
          .find( p => p.admin_level !== null && p.admin_level < 3 );
        if ( place ) {
          newState.query.place_id = place.id;
          newState.query.place = place;
          newState.query.defaultPlace = place;
        }
      } else if ( placeIDs && placeIDs.length > 0 ) {
        newState.query.place_id = placeIDs[placeIDs.length - 1];
      }
      newState.detailTaxon = null;
      newState.detailPhotoIndex = 0;
      newState.observation = observation;
      // Don't use the current observation when making suggestions based on nearby
      // observations
      newState.query.featured_observation_id = observation.id;
      newState.query.featured_observation_uuid = observation.uuid;
      break;
    }
    case UPDATE_CURRENT_OBSERVATION: {
      if ( action.updates.places ) {
        const place = _
          .sortBy( action.updates.places, p => p.bbox_area )
          .find( p => p.admin_level !== null && p.admin_level < 3 );
        if ( place ) {
          newState.query.place_id = place.id;
          newState.query.place = place;
          newState.query.defaultPlace = place;
        }
      }
      break;
    }
    default:
      // leave it alone
  }
  return newState;
}

function setSuggestions( suggestions ) {
  return { type: SET_SUGGESTIONS, suggestions };
}

function setQuery( query ) {
  return { type: SET_QUERY, query };
}

function startLoading( ) {
  return { type: START_LOADING };
}

function stopLoading( ) {
  return { type: STOP_LOADING };
}

export function updateQuery( query ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { testingApiV2 } = s.config;
    const newQuery = Object.assign( { }, s.suggestions.query, query );
    if ( query.place && !query.place_id ) {
      newQuery.place_id = query.place.id;
    }
    if ( query.taxon && !query.taxon_id ) {
      newQuery.taxon_id = query.taxon.id;
    }
    if (
      query.taxon_id
      && !query.taxon
      && s.suggestions.observation
      && s.suggestions.observation.taxon
      && s.suggestions.observation.taxon.id === query.taxon_id
    ) {
      newQuery.taxon = s.suggestions.observation.taxon;
    }
    if ( query.taxon_id && !query.taxon ) {
      const params = {};
      if ( testingApiV2 ) {
        params.fields = Object.assign( {}, TAXON_FIELDS, { ancestors: TAXON_FIELDS } );
      }
      inatjs.taxa.fetch( query.taxon_id, params )
        .then( response => {
          if ( response.results[0] ) {
            dispatch( updateQuery( {
              taxon: response.results[0],
              defaultTaxon: response.results[0]
            } ) );
          }
        } );
    }
    if ( query.place_id && !query.place ) {
      const params = { no_geom: true };
      if ( testingApiV2 ) {
        params.fields = {
          admin_level: true,
          id: true,
          uuid: true,
          name: true,
          display_name: true,
          place_type: true
        };
      }
      inatjs.places.fetch( query.place_id, params )
        .then( response => {
          if ( response.results[0] ) {
            dispatch( updateQuery( {
              place: response.results[0]
            } ) );
          }
        } );
    }
    dispatch( setQuery( newQuery ) );
  };
}

export function setDetailTaxon( taxon, options = null ) {
  return { type: SET_DETAIL_TAXON, taxon, options };
}

export function updateWithObservation( observation ) {
  return { type: UPDATE_WITH_OBSERVATION, observation };
}

function sanitizeQuery( query ) {
  return _.pick( query, ["place_id", "taxon_id", "source", "order_by", "featured_observation_id"] );
}

export function reset( ) {
  return { type: RESET };
}

export function fetchSuggestions( query ) {
  return function ( dispatch, getState ) {
    const s = getState( );
    const { testingApiV2 } = s.config;
    let newQuery = {};
    if ( query && _.keys( query ).length > 0 ) {
      newQuery = query;
    } else {
      newQuery = s.suggestions.query;
    }
    if ( _.keys( newQuery ).length === 0 ) {
      return null;
    }
    if ( testingApiV2 ) {
      newQuery.featured_observation_id = newQuery.featured_observation_uuid;
    }
    if (
      _.isEqual( sanitizeQuery( s.suggestions.responseQuery, newQuery ) )
      && s.suggestions.response.results.length > 0
    ) {
      // already loaded results for this query
      return null;
    }
    if ( newQuery.source === "misidentifications" && !newQuery.taxon_id ) {
      // can't show misidentifications of nothing
      return null;
    }
    dispatch( updateQuery( newQuery ) );
    dispatch( startLoading( ) );
    const sanitizedQuery = sanitizeQuery( newQuery );
    const payload = Object.assign( {}, sanitizedQuery, {
      locale: I18n.locale
    } );
    if ( testingApiV2 ) {
      payload.fields = {
        taxon: Object.assign( {}, TAXON_FIELDS, {
          taxon_photos: {
            photo: PHOTO_FIELDS
          }
        } )
      };
    }
    if ( payload.source === "visual" ) {
      const photo = s.suggestions.observation.photos[0];
      if ( !photo ) {
        // can't get visual results without a photo
        return null;
      }
      payload.image_url = photo.photoUrl( "medium" );
      if (
        s.suggestions.observation.geojson
      ) {
        payload.lat = s.suggestions.observation.geojson.coordinates[1];
        payload.lng = s.suggestions.observation.geojson.coordinates[0];
      }
    }
    return inatjs.taxa.suggest( _.omitBy( payload, _.isNull ) ).then( suggestions => {
      const currentQuery = getState( ).suggestions.query;
      if ( _.isEqual( sanitizeQuery( currentQuery ), sanitizedQuery ) ) {
        dispatch( stopLoading( ) );
        dispatch( setSuggestions( suggestions ) );
      }
    } ).catch( e => {
      dispatch( stopLoading( ) );
      alert( e );
    } );
  };
}

export function fetchDetailTaxon( ) {
  return function ( dispatch, getState ) {
    const { detailTaxon } = getState( ).suggestions;
    if ( !detailTaxon ) {
      return;
    }
    const params = {};
    const { testingApiV2 } = getState( ).config;
    if ( testingApiV2 ) {
      params.fields = Object.assign( {}, TAXON_FIELDS, {
        wikipedia_summary: true,
        ancestors: TAXON_FIELDS,
        children: TAXON_FIELDS,
        taxon_photos: { photo: PHOTO_FIELDS }
      } );
    }
    inatjs.taxa.fetch( detailTaxon.id, params ).then( response => {
      dispatch( setDetailTaxon( response.results[0] ) );
    } ).catch( e => alert( e ) );
  };
}
