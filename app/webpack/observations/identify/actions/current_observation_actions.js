import iNaturalistJS from "inaturalistjs";
import moment from "moment";
import _ from "lodash";
import { setConfig } from "../../../shared/ducks/config";
import { updateEditorContent } from "../../shared/ducks/text_editors";
import {
  incrementReviewed,
  decrementReviewed
} from "./observations_stats_actions";
import { updateObservationInCollection } from "./observations_actions";
import { showFinishedModal } from "./finished_modal_actions";
import {
  fetchSuggestions,
  updateWithObservation as updateSuggestionsWithObservation,
  reset as resetSuggestions
} from "../ducks/suggestions";
import { setControlledTermsForTaxon } from "../../show/ducks/controlled_terms";
import { fetchQualityMetrics, setQualityMetrics } from "../../show/ducks/quality_metrics";
import {
  fetchSubscriptions,
  resetSubscriptions,
  setSubscriptions
} from "../../show/ducks/subscriptions";
import { setConfirmModalState } from "../../../shared/ducks/confirm_modal";
import {
  addToProject as sharedAddToProject,
  removeFromProject as sharedRemoveFromProject,
  joinProject as sharedJoinProject,
  addObservationFieldValue as sharedAddObservationFieldValue,
  updateObservationFieldValue as sharedUpdateObservationFieldValue,
  removeObservationFieldValue as sharedRemoveObservationFieldValue
} from "../../shared/ducks/observation";
import { updateSession } from "../../show/ducks/users";
import { parseRailsErrorsResponse } from "../../../shared/util";
import { showAlert } from "../../../shared/ducks/alert_modal";

import {
  SHOW_CURRENT_OBSERVATION,
  HIDE_CURRENT_OBSERVATION,
  FETCH_CURRENT_OBSERVATION,
  RECEIVE_CURRENT_OBSERVATION,
  UPDATE_CURRENT_OBSERVATION,
  SHOW_NEXT_OBSERVATION,
  SHOW_PREV_OBSERVATION,
  ADD_IDENTIFICATION,
  ADD_COMMENT,
  LOADING_DISCUSSION_ITEM,
  STOP_LOADING_DISCUSSION_ITEM
} from "./current_observation_actions_names";

// order matters...
const TABS = ["info", "suggestions", "annotations", "data-quality"];

const USER_FIELDS = {
  id: true,
  login: true,
  icon_url: true
};
const MODERATOR_ACTION_FIELDS = {
  action: true,
  id: true,
  created_at: true,
  reason: true,
  user: USER_FIELDS
};
const TAXON_FIELDS = {
  ancestry: true,
  ancestor_ids: true,
  ancestors: {
    id: true,
    uuid: true,
    name: true,
    iconic_taxon_name: true,
    is_active: true,
    preferred_common_name: true,
    rank: true,
    rank_level: true
  },
  default_photo: {
    attribution: true,
    license_code: true,
    url: true,
    square_url: true
  },
  iconic_taxon_name: true,
  id: true,
  is_active: true,
  name: true,
  preferred_common_name: true,
  rank: true,
  rank_level: true
};
const CONTROLLED_TERM_FIELDS = {
  id: true,
  label: true,
  multivalued: true
};
const PROJECT_FIELDS = {
  admins: {
    user_id: true
  },
  icon: true,
  project_observation_fields: {
    id: true,
    observation_field: {
      allowed_values: true,
      datatype: true,
      description: true,
      id: true,
      name: true
    }
  },
  slug: true,
  title: true
};
const OBSERVATION_FIELDS = {
  annotations: {
    controlled_attribute: CONTROLLED_TERM_FIELDS,
    controlled_value: CONTROLLED_TERM_FIELDS,
    user: USER_FIELDS,
    vote_score: true,
    votes: {
      vote_flag: true,
      user: USER_FIELDS
    }
  },
  application: {
    id: true,
    icon: true,
    name: true,
    url: true
  },
  comments: {
    body: true,
    created_at: true,
    flags: { id: true },
    hidden: true,
    id: true,
    moderator_actions: MODERATOR_ACTION_FIELDS,
    spam: true,
    user: USER_FIELDS
  },
  community_taxon: TAXON_FIELDS,
  created_at: true,
  description: true,
  faves: {
    user: USER_FIELDS
  },
  flags: {
    id: true,
    flag: true,
    resolved: true
  },
  geojson: true,
  geoprivacy: true,
  id: true,
  identifications: {
    body: true,
    category: true,
    created_at: true,
    current: true,
    disagreement: true,
    flags: { id: true },
    hidden: true,
    moderator_actions: MODERATOR_ACTION_FIELDS,
    previous_observation_taxon: TAXON_FIELDS,
    spam: true,
    taxon: TAXON_FIELDS,
    taxon_change: { id: true, type: true },
    updated_at: true,
    user: USER_FIELDS,
    uuid: true,
    vision: true
  },
  identifications_most_agree: true,
  // TODO refactor to rely on geojson instead of lat and lon
  latitude: true,
  license_code: true,
  location: true,
  longitude: true,
  map_scale: true,
  non_traditional_projects: {
    current_user_is_member: true,
    project_user: {
      user: USER_FIELDS
    },
    project: PROJECT_FIELDS
  },
  obscured: true,
  observed_on: true,
  observed_time_zone: true,
  ofvs: {
    observation_field: {
      allowed_values: true,
      datatype: true,
      description: true,
      name: true,
      taxon: {
        name: true
      },
      uuid: true
    },
    user: USER_FIELDS,
    uuid: true,
    value: true,
    taxon: TAXON_FIELDS
  },
  outlinks: {
    source: true,
    url: true
  },
  observation_photos: {
    id: true
  },
  photos: {
    id: true,
    uuid: true,
    url: true,
    license_code: true
  },
  place_guess: true,
  place_ids: true,
  positional_accuracy: true,
  preferences: {
    prefers_community_taxon: true
  },
  private_geojson: true,
  private_place_guess: true,
  private_place_ids: true,
  project_observations: {
    current_user_is_member: true,
    preferences: {
      allows_curator_coordinate_access: true
    },
    project: PROJECT_FIELDS,
    uuid: true
  },
  public_positional_accuracy: true,
  quality_grade: true,
  quality_metrics: {
    id: true,
    metric: true,
    agree: true,
    user: USER_FIELDS
  },
  reviewed_by: true,
  sounds: {
    file_url: true,
    file_content_type: true,
    id: true,
    license_code: true,
    play_local: true,
    url: true,
    uuid: true
  },
  tags: true,
  taxon: TAXON_FIELDS,
  taxon_geoprivacy: true,
  time_observed_at: true,
  time_zone: true,
  user: {
    ...USER_FIELDS,
    name: true,
    observations_count: true,
    preferences: {
      prefers_community_taxa: true,
      prefers_observation_fields_by: true
    }
  },
  viewer_trusted_by_observer: true,
  votes: {
    id: true,
    user: USER_FIELDS,
    vote_flag: true,
    vote_scope: true
  }
};

function showCurrentObservation( observation ) {
  return {
    type: SHOW_CURRENT_OBSERVATION,
    observation
  };
}

function hideCurrentObservation( ) {
  return { type: HIDE_CURRENT_OBSERVATION };
}

function receiveCurrentObservation( observation, others ) {
  return Object.assign( { }, others, {
    type: RECEIVE_CURRENT_OBSERVATION,
    observation
  } );
}

function updateCurrentObservation( updates, options = { } ) {
  return Object.assign( { }, {
    type: UPDATE_CURRENT_OBSERVATION,
    updates,
    observation_id: options.observation_id
  } );
}

export function fetchDataForTab( options = { } ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const observation = options.observation || s.currentObservation.observation;
    if ( s.currentObservation.tab === "suggestions" ) {
      dispatch( updateSuggestionsWithObservation( observation ) );
      dispatch( fetchSuggestions( ) );
    } else if ( s.currentObservation.tab === "annotations" ) {
      dispatch( setControlledTermsForTaxon( observation.taxon ) );
    } else if ( s.currentObservation.tab === "data-quality" ) {
      dispatch( fetchQualityMetrics( { observation } ) );
    } else {
      dispatch( resetSubscriptions( ) );
    }
  };
}

function fetchObservation( observation ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const obs = observation;
    const { currentUser, preferredPlace } = s.config;
    const params = {
      preferred_place_id: preferredPlace ? preferredPlace.id : null,
      locale: I18n.locale,
      // Need this to check if a project curator has permission to see the
      // coordinates
      include_new_projects: true
    };
    let fetchIDs = [obs.id];
    if ( s.config.testingApiV2 ) {
      params.fields = OBSERVATION_FIELDS;
      fetchIDs = [obs.uuid];
    }
    return iNaturalistJS.observations.fetch( fetchIDs, params )
      .then( response => {
        const newObs = response.results[0];
        let captiveByCurrentUser = false;
        if ( currentUser && newObs && newObs.quality_metrics ) {
          const userQualityMetric = _.find( newObs.quality_metrics, qm => (
            qm.user && qm.user.id === currentUser.id && qm.metric === "wild"
          ) );
          if ( userQualityMetric ) {
            captiveByCurrentUser = !userQualityMetric.agree;
          }
        }
        let reviewedByCurrentUser = false;
        if ( currentUser && newObs ) {
          reviewedByCurrentUser = newObs.reviewed_by.indexOf( currentUser.id ) > -1;
        }
        let currentUserIdentification;
        if ( currentUser && newObs && newObs.identifications ) {
          currentUserIdentification = _.find( newObs.identifications, ident => (
            ident.user.id === currentUser.id && ident.current
          ) );
        }
        newObs.currentUserAgrees = currentUserIdentification
          && currentUserIdentification.taxon_id === newObs.taxon_id;
        dispatch( updateObservationInCollection( newObs, {
          captiveByCurrentUser,
          reviewedByCurrentUser,
          currentUserAgrees: newObs.currentUserAgrees,
          taxon: newObs.taxon,
          quality_grade: newObs.quality_grade
        } ) );
        const currentState = getState();
        if (
          currentState.currentObservation.observation
          && currentState.currentObservation.observation.id === obs.id
        ) {
          dispatch( receiveCurrentObservation( newObs, {
            captiveByCurrentUser,
            reviewedByCurrentUser,
            currentUserIdentification
          } ) );
        }
        return newObs;
      } )
      .then( o => {
        if ( o.places ) {
          return o;
        }
        if ( s.observations && s.observations.placesByID ) {
          const oPlaceIDs = _.uniq( _.flatten( [o.place_ids, o.private_place_ids] ) );
          const cachedPlaces = _.compact( oPlaceIDs.map( pid => s.observations.placesByID[pid] ) );
          if (
            cachedPlaces
            && cachedPlaces.length > 0
            && s.currentObservation.observation
            && s.currentObservation.observation.id === o.id
          ) {
            dispatch( updateCurrentObservation( { places: cachedPlaces } ) );
            o.places = cachedPlaces;
            return o;
          }
        }
        let placeIDs;
        if ( o.private_place_ids && o.private_place_ids.length > 0 ) {
          placeIDs = o.private_place_ids;
        } else {
          placeIDs = o.place_ids;
        }
        if ( placeIDs && placeIDs.length > 0 ) {
          placeIDs = _.take( o.place_ids, 100 );
          if ( placeIDs.length === 0 ) {
            return o;
          }
          const placeParams = { per_page: 100, no_geom: true };
          if ( s.config.testingApiV2 ) {
            placeParams.fields = {
              id: true,
              name: true,
              display_name: true,
              admin_level: true,
              bbox_area: true
            };
          }
          return iNaturalistJS.places.fetch( placeIDs, placeParams )
            .then( response => {
              if ( getState( ).currentObservation.observation.id === o.id ) {
                dispatch( updateCurrentObservation( { places: response.results } ) );
                return Object.assign( o, { places: response.results } );
              }
              return o;
            } )
            .catch( ( ) => o );
        }
        return o;
      } )
      .then( finalObservation => {
        dispatch( resetSuggestions( ) );
        dispatch( fetchDataForTab( { observation: finalObservation } ) );
      } );
  };
}

function fetchCurrentObservation( observation = null ) {
  return ( dispatch, getState ) => {
    const s = getState();
    // Theoretically there's no reason to fetch the obs if the modal isn't even
    // visible
    if ( !s.currentObservation.visible ) {
      return Promise.resolve( );
    }
    if (
      observation
      && s.currentObservation.observation
      && observation.id !== s.currentObservation.observation.id
    ) {
      // Don't bother fetching an observation that we're no longer looking at
      return Promise.resolve( );
    }
    return dispatch( fetchObservation( observation || s.currentObservation.observation ) );
  };
}

function showNextObservation( ) {
  return ( dispatch, getState ) => {
    const { observations, currentObservation, config } = getState();
    let nextObservation;
    if ( currentObservation.visible ) {
      let nextIndex = _.findIndex( observations.results, o => (
        o.id === currentObservation.observation.id
      ) );
      if ( nextIndex === null || nextIndex === undefined ) { return; }
      nextIndex += 1;
      nextObservation = observations.results[nextIndex];
    } else {
      nextObservation = currentObservation.observation || observations.results[0];
    }
    if ( nextObservation ) {
      dispatch( setControlledTermsForTaxon( nextObservation.taxon ) );
      dispatch( showCurrentObservation( nextObservation ) );
      dispatch( fetchCurrentObservation( nextObservation ) );
    } else {
      dispatch( hideCurrentObservation( ) );
      dispatch( showFinishedModal( ) );
    }
    dispatch( updateEditorContent( "obsIdentifyIdComment", "" ) );
    if ( !config.mapZoomLevelLocked
      && !_.isNumber( config.currentUser.preferred_identify_map_zoom_level ) ) {
      dispatch( setConfig( { mapZoomLevel: undefined } ) );
    }
  };
}

function showPrevObservation( ) {
  return ( dispatch, getState ) => {
    const { observations, currentObservation } = getState();
    if ( !currentObservation.visible ) {
      return;
    }
    let prevIndex = _.findIndex( observations.results, o => (
      o.id === currentObservation.observation.id
    ) );
    if ( prevIndex === null || prevIndex === undefined ) { return; }
    prevIndex -= 1;
    const prevObservation = observations.results[prevIndex];
    if ( prevObservation ) {
      dispatch( setControlledTermsForTaxon( prevObservation.taxon ) );
      dispatch( showCurrentObservation( prevObservation ) );
      dispatch( fetchCurrentObservation( prevObservation ) );
    }
    dispatch( updateEditorContent( "obsIdentifyIdComment", "" ) );
  };
}

function toggleKeyboardShortcuts( ) {
  return ( dispatch, getState ) => {
    dispatch( updateCurrentObservation( {
      keyboardShortcutsShown: !getState( ).currentObservation.keyboardShortcutsShown
    } ) );
  };
}

function addIdentification( ) {
  return {
    type: ADD_IDENTIFICATION
  };
}

function addComment( ) {
  return {
    type: ADD_COMMENT
  };
}

function toggleQualityMetric( observation, metric, agree ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const params = {
      id: s.config.testingApiV2 ? observation.uuid : observation.id,
      metric
    };
    if ( agree ) {
      iNaturalistJS.observations.deleteQualityMetric( params ).then(
        ( ) => {
          dispatch( fetchCurrentObservation( observation ) );
        }
      );
    } else {
      params.agree = "false";
      iNaturalistJS.observations.setQualityMetric( params ).then(
        ( ) => {
          dispatch( fetchCurrentObservation( observation ) );
        }
      ).catch( e => {
        e.response.text( ).then( text => {
          const railsErrors = parseRailsErrorsResponse( text ) || [I18n.t( "failed_to_save_record" )];
          dispatch( showAlert(
            railsErrors.join( "," ),
            { title: I18n.t( "request_failed" ) }
          ) );
        } ).catch( ( ) => {
          dispatch( showAlert(
            I18n.t( "failed_to_save_record" ),
            { title: I18n.t( "request_failed" ) }
          ) );
        } );
        throw e;
      } );
    }
  };
}

function toggleCaptive( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { observation } = s.currentObservation;
    const agree = observation.captiveByCurrentUser;
    dispatch( updateCurrentObservation( {
      captiveByCurrentUser: !observation.captiveByCurrentUser,
      reviewedByCurrentUser: s.config?.currentUserCanInteractWithResource( observation )
    } ) );
    if ( !observation.reviewedByCurrentUser
      && s.config?.currentUserCanInteractWithResource( observation )
    ) {
      const reviewParams = {
        id: s.config.testingApiV2 ? observation.uuid : observation.id
      };
      iNaturalistJS.observations.review( reviewParams );
    }
    dispatch( toggleQualityMetric( observation, "wild", agree ) );
  };
}

function toggleReviewed( optionalObs = null ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const observation = optionalObs || s.currentObservation.observation;
    if ( !s.config?.currentUserCanInteractWithResource( observation ) ) {
      return;
    }
    const reviewed = observation.reviewedByCurrentUser;
    const params = { id: observation.id, skip_refresh: true };
    if (
      s.currentObservation.observation
      && observation.id === s.currentObservation.observation.id
    ) {
      dispatch( updateCurrentObservation( {
        reviewedByCurrentUser: !reviewed
      } ) );
    }
    dispatch( updateObservationInCollection( observation, {
      reviewedByCurrentUser: !reviewed
    } ) );
    if ( s.config.testingApiV2 ) {
      params.id = observation.uuid;
    }
    if ( reviewed ) {
      dispatch( setConfig( { allReviewed: false } ) );
      iNaturalistJS.observations.unreview( params ).then( ( ) => {
        dispatch( decrementReviewed( ) );
      } );
    } else {
      iNaturalistJS.observations.review( params ).then( ( ) => {
        dispatch( incrementReviewed( ) );
        if ( _.isEmpty( _.filter(
          getState( ).observations.results,
          o => !o.reviewedByCurrentUser
        ) ) ) {
          dispatch( setConfig( { allReviewed: true } ) );
        }
      } );
    }
  };
}

function loadingDiscussionItem( item ) {
  return { type: LOADING_DISCUSSION_ITEM, item };
}

function stopLoadingDiscussionItem( item ) {
  return { type: STOP_LOADING_DISCUSSION_ITEM, item };
}

export function addAnnotation( controlledAttribute, controlledValue, options = {} ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const newAnnotations = ( state.currentObservation.observation.annotations || [] ).concat( [{
      controlled_attribute: controlledAttribute,
      controlled_value: controlledValue,
      user: state.config.currentUser,
      api_status: "saving"
    }] );
    dispatch( updateSession( {
      prefers_hide_identify_annotations: false
    } ) );
    dispatch( updateCurrentObservation(
      { annotations: newAnnotations },
      { observation_id: state.currentObservation.observation.id }
    ) );

    const payload = {
      resource_type: "Observation",
      resource_id: state.config.testingApiV2
        ? state.currentObservation.observation.uuid
        : state.currentObservation.observation.id,
      controlled_attribute_id: controlledAttribute.id,
      controlled_value_id: controlledValue.id
    };
    iNaturalistJS.annotations.create( payload )
      .then( () => dispatch( fetchCurrentObservation( ) ) )
      .catch( e => {
        console.log( "[DEBUG] Faile to add annotation: ", e );
      } );
  };
}

export function addAnnotationFromKeyboard( attributeLabel, valueLabel ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    if ( !s.currentObservation.observation || s.currentObservation.tab !== "annotations" ) {
      return;
    }
    const attribute = s.controlledTerms.terms.find( a => a.label === attributeLabel );
    if ( !attribute ) { return; }
    const value = attribute.values.find( v => v.label === valueLabel );
    if ( !value ) { return; }
    const existing = s.currentObservation.observation.annotations.find(
      a => a.controlled_value && a.controlled_attribute
        && a.controlled_attribute.id === attribute.id
        && ( !a.controlled_attribute.multivalued || a.controlled_value.id === value.id )
    );
    if ( !existing ) {
      dispatch( addAnnotation( attribute, value ) );
    }
  };
}

export function deleteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const newAnnotations = _.map( state.currentObservation.observation.annotations, a => (
      ( a.user.id === state.config.currentUser.id && a.uuid === id )
        ? Object.assign( { }, a, { api_status: "deleting" } )
        : a
    ) );
    dispatch( updateCurrentObservation( { annotations: newAnnotations } ) );
    iNaturalistJS.annotations.delete( { id } )
      .then( () => dispatch( fetchCurrentObservation( ) ) )
      .catch( e => {
        console.log( "[DEBUG] Failed to delete annotation: ", e );
      } );
  };
}

export function voteAnnotation( id, voteValue ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const newAnnotations = _.map( state.currentObservation.observation.annotations, a => (
      ( a.uuid === id )
        ? Object.assign( { }, a, {
          api_status: "voting",
          votes: ( a.votes || [] ).concat( [{
            vote_flag: ( voteValue !== "bad" ),
            user: state.config.currentUser,
            api_status: "saving"
          }] )
        } )
        : a
    ) );
    dispatch( updateCurrentObservation( { annotations: newAnnotations } ) );
    iNaturalistJS.annotations.vote( { id, vote: voteValue } )
      .then( () => dispatch( fetchCurrentObservation( ) ) )
      .catch( e => {
        console.log( "[DEBUG] Failed to vote on annotation: ", e );
      } );
  };
}

export function unvoteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const newAnnotations = _.map( state.currentObservation.observation.annotations, a => (
      ( a.uuid === id ) ? {
        ...a,
        api_status: "voting",
        votes: _.map( a.votes, v => (
          v.user.id === state.config.currentUser.id
            ? { ...v, api_status: "deleting" }
            : v
        ) )
      } : a
    ) );
    dispatch( updateCurrentObservation( { annotations: newAnnotations } ) );
    iNaturalistJS.annotations.unvote( { id } )
      .then( () => dispatch( fetchCurrentObservation( ) ) )
      .catch( e => {
        console.log( "[DEBUG] Failed to unvote on annotation: ", e );
      } );
  };
}

export function vote( scope, params = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const payload = {
      id: state.config.testingApiV2
        ? state.currentObservation.observation.uuid
        : state.currentObservation.observation.id,
      ...params
    };
    if ( scope ) {
      payload.scope = scope;
      const newVotes = _.filter(
        state.currentObservation.observation.votes,
        v => (
          !( v.user.id === state.config.currentUser.id && v.vote_scope === scope )
        )
      ).concat( [{
        vote_flag: ( params.vote === "yes" ),
        vote_scope: payload.scope,
        user: state.config.currentUser,
        api_status: "saving"
      }] );
      dispatch( updateCurrentObservation( { votes: newVotes } ) );
    } else {
      payload.skip_refresh = true;
    }
    iNaturalistJS.observations.fave( payload )
      .then( () => dispatch( fetchCurrentObservation( ) ) )
      .catch( e => {
        e.response.text( ).then( text => {
          const railsErrors = parseRailsErrorsResponse( text ) || [I18n.t( "failed_to_save_record" )];
          dispatch( showAlert(
            railsErrors.join( "," ),
            { title: I18n.t( "request_failed" ) }
          ) );
        } ).catch( ( ) => {
          dispatch( showAlert(
            I18n.t( "failed_to_save_record" ),
            { title: I18n.t( "request_failed" ) }
          ) );
        } );
        throw e;
      } );
  };
}

export function unvote( scope ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const payload = {
      id: state.config.testingApiV2
        ? state.currentObservation.observation.uuid
        : state.currentObservation.observation.id
    };
    if ( scope ) {
      payload.scope = scope;
      const newVotes = _.map( state.currentObservation.observation.votes, v => (
        ( v.user.id === state.config.currentUser.id && v.vote_scope === scope )
          ? { ...v, api_status: "deleting" }
          : v
      ) );
      dispatch( updateCurrentObservation( { votes: newVotes } ) );
    } else {
      payload.skip_refresh = true;
    }
    iNaturalistJS.observations.unfave( payload )
      .then( () => dispatch( fetchCurrentObservation( ) ) )
      .catch( e => {
        console.log( "[DEBUG] Faile to add annotation: ", e );
      } );
  };
}

export function fave( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const newFaves = state.currentObservation.observation.faves.concat( [{
      votable_id: state.currentObservation.observation.id,
      user: state.config.currentUser,
      temporary: true
    }] );
    dispatch( updateCurrentObservation( { faves: newFaves } ) );
    dispatch( vote( ) );
  };
}

export function unfave( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const newFaves = state.currentObservation.observation.faves.filter( f => (
      f.user.id !== state.config.currentUser.id
    ) );
    dispatch( updateCurrentObservation( { faves: newFaves } ) );
    dispatch( unvote( ) );
  };
}

export function toggleFave( ) {
  return ( dispatch, getState ) => {
    const { config, currentObservation } = getState( );
    const { observation } = currentObservation;
    const userHasFavedThis = observation && observation.faves && _.find( observation.faves, o => (
      o.user.id === config.currentUser.id
    ) );
    if ( userHasFavedThis ) {
      dispatch( unfave( ) );
    } else {
      dispatch( fave( ) );
    }
  };
}

export function voteMetric( metric, params = { } ) {
  if ( metric === "needs_id" ) {
    return vote( "needs_id", { vote: ( params.agree === "false" ) ? "no" : "yes" } );
  }
  return ( dispatch, getState ) => {
    const state = getState( );
    const newMetrics = _.filter( state.qualityMetrics, qm => (
      !( qm.user && qm.user.id === state.config.currentUser.id && qm.metric === metric )
    ) ).concat( [{
      observation_id: state.currentObservation.observation.id,
      metric,
      agree: ( params.agree !== "false" ),
      created_at: moment( ).format( ),
      user: state.config.currentUser,
      api_status: "saving"
    }] );
    dispatch( setQualityMetrics( newMetrics ) );
    const payload = {
      id: state.config.testingApiV2
        ? state.currentObservation.observation.uuid
        : state.currentObservation.observation.id,
      metric,
      ...params
    };
    iNaturalistJS.observations.setQualityMetric( payload, { fetchQualityMetrics: true } )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}

export function unvoteMetric( metric ) {
  if ( metric === "needs_id" ) {
    return unvote( "needs_id" );
  }
  return ( dispatch, getState ) => {
    const state = getState( );
    const newMetrics = _.map( state.qualityMetrics, qm => (
      ( qm.user.id === state.config.currentUser.id && qm.metric === metric )
        ? { ...qm, api_status: "deleting" }
        : qm
    ) );
    dispatch( setQualityMetrics( newMetrics ) );
    const payload = {
      id: state.config.testingApiV2
        ? state.currentObservation.observation.uuid
        : state.currentObservation.observation.id,
      metric
    };
    iNaturalistJS.observations.deleteQualityMetric( payload, { fetchQualityMetrics: true } )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}

export function createFlag( className, id, flag, body ) {
  return dispatch => {
    const params = {
      flag: {
        flaggable_type: className,
        flaggable_id: id,
        flag
      }
    };
    if ( body ) {
      params.flag.flag_explanation = body;
    }
    iNaturalistJS.flags.create( params )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}

export function deleteFlag( id ) {
  return dispatch => {
    iNaturalistJS.flags.delete( { id } )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}

export function zoomCurrentPhoto( ) {
  return ( ) => {
    const div = $( ".image-gallery-slide.center .easyzoom" );
    const easyZoom = div.data( "easyZoom" );
    if ( !easyZoom ) { return; }
    if ( easyZoom.isOpen ) {
      easyZoom.hide( );
    } else {
      const e = new MouseEvent( "mouseover", {
        clientX: div.offset( ).left + ( div.width( ) / 2 ),
        clientY: div.offset( ).top + ( div.height( ) / 2 )
      } );
      easyZoom.show( e );
    }
  };
}

export function showPrevPhoto( ) {
  return ( dispatch, getState ) => {
    const state = getState( ).currentObservation;
    if (
      !state.observation
      || !state.observation.photos
      || state.observation.photos.length <= 1
    ) {
      return;
    }
    let newCurrentIndex = state.imagesCurrentIndex || 0;
    if ( newCurrentIndex > 0 ) {
      newCurrentIndex -= 1;
    }
    dispatch( updateCurrentObservation( { imagesCurrentIndex: newCurrentIndex } ) );
  };
}

export function showNextPhoto( ) {
  return ( dispatch, getState ) => {
    const state = getState( ).currentObservation;
    if (
      !state.observation
      || !state.observation.photos
      || state.observation.photos.length <= 1
    ) {
      return;
    }
    let newCurrentIndex = state.imagesCurrentIndex || 0;
    if ( newCurrentIndex < state.observation.photos.length - 1 ) {
      newCurrentIndex += 1;
    }
    dispatch( updateCurrentObservation( { imagesCurrentIndex: newCurrentIndex } ) );
  };
}

export function showPrevTab( ) {
  return ( dispatch, getState ) => {
    let index = TABS.indexOf( getState( ).currentObservation.tab );
    if ( index <= 0 ) {
      index = 0;
    } else {
      index -= 1;
    }
    dispatch( updateCurrentObservation( { tab: TABS[index] } ) );
    dispatch( fetchDataForTab( ) );
  };
}

export function showNextTab( ) {
  return ( dispatch, getState ) => {
    let index = TABS.indexOf( getState( ).currentObservation.tab );
    if ( index < 0 ) {
      index = 0;
    } else if ( index < TABS.length - 1 ) {
      index += 1;
    }
    dispatch( updateCurrentObservation( { tab: TABS[index] } ) );
    dispatch( fetchDataForTab( ) );
  };
}

export function addToProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( sharedAddToProject(
      state.currentObservation.observation,
      project,
      updateCurrentObservation,
      ( ) => {
        dispatch( fetchCurrentObservation( ) );
      }
    ) );
  };
}

export function removeFromProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( sharedRemoveFromProject(
      state.currentObservation.observation,
      project,
      updateCurrentObservation,
      ( ) => {
        dispatch( fetchCurrentObservation( ) );
      }
    ) );
  };
}

export function confirmRemoveFromProject( project ) {
  return dispatch => {
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "are_you_sure_you_want_to_remove_this_observation_from_project", { project: project.title } ),
      confirmText: I18n.t( "yes" ),
      onConfirm: ( ) => {
        dispatch( removeFromProject( project ) );
      }
    } ) );
  };
}

export function joinProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( sharedJoinProject(
      state.currentObservation.observation,
      project,
      updateCurrentObservation,
      ( ) => {
        dispatch( fetchCurrentObservation( ) );
      }
    ) );
  };
}

export function addObservationFieldValue( options ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( sharedAddObservationFieldValue(
      state.currentObservation.observation,
      updateCurrentObservation,
      ( ) => {
        dispatch( fetchCurrentObservation( ) );
      },
      options
    ) );
  };
}

export function updateObservationFieldValue( id, options ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( sharedUpdateObservationFieldValue(
      state.currentObservation.observation,
      id,
      updateCurrentObservation,
      ( ) => {
        dispatch( fetchCurrentObservation( ) );
      },
      options
    ) );
  };
}

export function removeObservationFieldValue( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( sharedRemoveObservationFieldValue(
      state.currentObservation.observation,
      id,
      updateCurrentObservation,
      ( ) => {
        dispatch( fetchCurrentObservation( ) );
      }
    ) );
  };
}

export function followUser( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.currentObservation.observation ) { return; }
    const obs = state.currentObservation.observation;
    if ( !obs.user ) { return; }
    const { currentUser } = state.config;
    const obsUser = obs.user;
    if ( obsUser.id === currentUser.id ) {
      return;
    }
    const newSubscriptions = state.subscriptions.subscriptions.concat( [{
      resource_type: "User",
      resource_id: obsUser.id,
      user_id: currentUser.id,
      api_status: "saving"
    }] );
    dispatch( setSubscriptions( newSubscriptions ) );
    const payload = {
      id: currentUser.id,
      friend_id: obsUser.id
    };
    const observation = { id: obs.id };
    iNaturalistJS.users.update( payload ).then(
      ( ) => dispatch( fetchSubscriptions( { observation } ) )
    );
  };
}

export function unfollowUser( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.currentObservation.observation ) { return; }
    const obs = state.currentObservation.observation;
    const obsUser = obs.user;
    const { currentUser } = state.config;
    if ( !obsUser ) { return; }
    if ( obsUser.id === currentUser.id ) {
      return;
    }
    const newSubscriptions = _.map( state.subscriptions.subscriptions, s => (
      s.resource_type === "User" && s.resource_id === obsUser.id
        ? Object.assign( { }, s, { api_status: "deleting" } )
        : s
    ) );
    dispatch( setSubscriptions( newSubscriptions ) );
    const observation = { id: obs.id };
    const payload = {
      id: currentUser.id,
      remove_friend_id: obsUser.id
    };
    iNaturalistJS.users.update( payload ).then(
      ( ) => dispatch( fetchSubscriptions( { observation } ) )
    );
  };
}

export function subscribe( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.currentObservation.observation ) { return; }
    if ( !state.currentObservation.observation.user ) { return; }
    if ( state.currentObservation.observation.user.id === state.config.currentUser.id ) {
      return;
    }
    const observation = { id: state.currentObservation.observation.id };
    const obsSubscription = _.find( state.subscriptions.subscriptions, s => (
      s.resource_type === "Observation" && s.resource_id === observation.id ) );
    if ( obsSubscription ) {
      const newSubscriptions = _.map( state.subscriptions.subscriptions, s => (
        s.resource_type === "Observation" && s.resource_id === observation.id
          ? Object.assign( { }, s, { api_status: "deleting" } )
          : s
      ) );
      dispatch( setSubscriptions( newSubscriptions ) );
    } else {
      const newSubscriptions = state.subscriptions.subscriptions.concat( [{
        resource_type: "Observation",
        resource_id: observation.id,
        user_id: state.config.currentUser.id,
        api_status: "saving"
      }] );
      dispatch( setSubscriptions( newSubscriptions ) );
    }
    const payload = { id: observation.id };
    iNaturalistJS.observations.subscribe( payload ).then( ( ) => {
      dispatch( fetchSubscriptions( { observation } ) );
    } );
  };
}

export function togglePlayFirstSound( ) {
  return ( ) => {
    const player = $( ".obs-media .sounds" ).find( "audio:first" )[0];
    const hasFocus = player === document.activeElement;
    if ( !player ) {
      return;
    }
    if ( !hasFocus ) {
      player.focus();
    }
    if ( player.paused ) {
      player.play( );
    } else {
      player.pause( );
    }
  };
}

export function addProjects( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { config } = s;
    if ( !s.currentObservation.observation || s.currentObservation.tab !== "annotations" ) {
      return;
    }
    if ( config.currentUser.prefers_hide_identify_projects ) {
      dispatch( updateSession( {
        prefers_hide_identify_projects: false
      } ) );
    }
  };
}

export function addObservationFields( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { config } = s;
    if ( !s.currentObservation.observation || s.currentObservation.tab !== "annotations" ) {
      return;
    }
    if ( config.currentUser.prefers_hide_identify_observation_fields ) {
      dispatch( updateSession( {
        prefers_hide_identify_observation_fields: false
      } ) );
    }
  };
}

export {
  SHOW_CURRENT_OBSERVATION,
  HIDE_CURRENT_OBSERVATION,
  FETCH_CURRENT_OBSERVATION,
  RECEIVE_CURRENT_OBSERVATION,
  UPDATE_CURRENT_OBSERVATION,
  SHOW_NEXT_OBSERVATION,
  SHOW_PREV_OBSERVATION,
  ADD_COMMENT,
  ADD_IDENTIFICATION,
  LOADING_DISCUSSION_ITEM,
  STOP_LOADING_DISCUSSION_ITEM,
  TABS,
  showCurrentObservation,
  hideCurrentObservation,
  fetchCurrentObservation,
  fetchObservation,
  receiveCurrentObservation,
  showNextObservation,
  showPrevObservation,
  addComment,
  addIdentification,
  toggleQualityMetric,
  toggleCaptive,
  toggleReviewed,
  loadingDiscussionItem,
  stopLoadingDiscussionItem,
  updateCurrentObservation,
  toggleKeyboardShortcuts
};
