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

const SHOW_CURRENT_OBSERVATION = "show_current_observation";
const HIDE_CURRENT_OBSERVATION = "hide_current_observation";
const FETCH_CURRENT_OBSERVATION = "fetch_current_observation";
const RECEIVE_CURRENT_OBSERVATION = "receive_current_observation";
const UPDATE_CURRENT_OBSERVATION = "update_current_observation";
const SHOW_NEXT_OBSERVATION = "show_next_observation";
const SHOW_PREV_OBSERVATION = "show_prev_observation";
const ADD_IDENTIFICATION = "add_identification";
const ADD_COMMENT = "add_comment";
const LOADING_DISCUSSION_ITEM = "loading_discussion_item";
const STOP_LOADING_DISCUSSION_ITEM = "stop_loading_discussion_item";

// order matters...
const TABS = ["info", "suggestions", "annotations", "data-quality"];

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

function updateCurrentObservation( updates ) {
  return Object.assign( { }, {
    type: UPDATE_CURRENT_OBSERVATION,
    updates
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
    return iNaturalistJS.observations.fetch( [obs.id], params )
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
          return iNaturalistJS.places.fetch(
            placeIDs, { per_page: 100, no_geom: true }
          ).then( response => {
            if ( getState( ).currentObservation.observation.id === o.id ) {
              dispatch( updateCurrentObservation( { places: response.results } ) );
              return Object.assign( o, { places: response.results } );
            }
            return o;
          } ).catch( ( ) => o );
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
    const { observations, currentObservation } = getState();
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
      dispatch( setControlledTermsForTaxon( nextObservation.taoxn ) );
      dispatch( showCurrentObservation( nextObservation ) );
      dispatch( fetchCurrentObservation( nextObservation ) );
    } else {
      dispatch( hideCurrentObservation( ) );
      dispatch( showFinishedModal( ) );
    }
    dispatch( updateEditorContent( "obsIdentifyIdComment", "" ) );
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
      dispatch( setControlledTermsForTaxon( prevObservation.taoxn ) );
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
  return dispatch => {
    const params = {
      id: observation.id,
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
      );
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
      reviewedByCurrentUser: true
    } ) );
    if ( !observation.reviewedByCurrentUser ) {
      iNaturalistJS.observations.review( { id: observation.id } );
    }
    dispatch( toggleQualityMetric( observation, "wild", agree ) );
  };
}

function toggleReviewed( optionalObs = null ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const observation = optionalObs || s.currentObservation.observation;
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
    if ( reviewed ) {
      dispatch( setConfig( { allReviewed: false } ) );
      iNaturalistJS.observations.unreview( params ).then( ( ) => {
        dispatch( decrementReviewed( ) );
      } );
    } else {
      iNaturalistJS.observations.review( params ).then( ( ) => {
        dispatch( incrementReviewed( ) );
        if ( _.isEmpty( _.filter( getState( ).observations.results,
          o => !o.reviewedByCurrentUser ) )
        ) {
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

export function addAnnotation( controlledAttribute, controlledValue ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const newAnnotations = ( state.currentObservation.observation.annotations || [] ).concat( [{
      controlled_attribute: controlledAttribute,
      controlled_value: controlledValue,
      user: state.config.currentUser,
      api_status: "saving"
    }] );
    dispatch( updateCurrentObservation( { annotations: newAnnotations } ) );

    const payload = {
      resource_type: "Observation",
      resource_id: state.currentObservation.observation.id,
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
      ( a.uuid === id )
        ? Object.assign( { }, a, {
          api_status: "voting",
          votes: _.map( a.votes, v => (
            v.user.id === state.config.currentUser.id
              ? Object.assign( { }, v, { api_status: "deleting" } )
              : v
          ) )
        } )
        : a
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
    const payload = Object.assign( { }, { id: state.currentObservation.observation.id }, params );
    if ( scope ) {
      payload.scope = scope;
      const newVotes = _.filter(
        state.currentObservation.observation.votes, v => (
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
        console.log( "[DEBUG] Faile to add annotation: ", e );
      } );
  };
}

export function unvote( scope ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const payload = { id: state.currentObservation.observation.id };
    if ( scope ) {
      payload.scope = scope;
      const newVotes = _.map( state.currentObservation.observation.votes, v => (
        ( v.user.id === state.config.currentUser.id && v.vote_scope === scope )
          ? Object.assign( { }, v, { api_status: "deleting" } )
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
    const payload = Object.assign( { },
      { id: state.currentObservation.observation.id, metric }, params );
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
        ? Object.assign( { }, qm, { api_status: "deleting" } )
        : qm
    ) );
    dispatch( setQualityMetrics( newMetrics ) );
    const payload = { id: state.currentObservation.observation.id, metric };
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
      },
      flag_explanation: body
    };
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

export function addObservationFieldValue( options ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !options.observationField ) { return; }
    const newOfvs = _.clone( state.currentObservation.observation.ofvs );
    newOfvs.unshift( {
      datatype: options.observationField.datatype,
      name: options.observationField.name,
      value: options.value,
      observation_field: options.observationField,
      api_status: "saving",
      taxon: options.taxon
    } );
    dispatch( updateCurrentObservation( { ofvs: newOfvs } ) );
    const payload = {
      observation_field_id: options.observationField.id,
      observation_id: state.currentObservation.observation.id,
      value: options.value
    };
    iNaturalistJS.observation_field_values.create( payload )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}

export function updateObservationFieldValue( id, options ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !options.observationField ) { return; }
    const newOfvs = state.currentObservation.observation.ofvs.map( ofv => (
      ofv.uuid === id ? {
        datatype: options.observationField.datatype,
        name: options.observationField.name,
        value: options.value,
        observation_field: options.observationField,
        api_status: "saving",
        taxon: options.taxon
      } : ofv ) );
    dispatch( updateCurrentObservation( { ofvs: newOfvs } ) );
    const payload = {
      id,
      observation_field_id: options.observationField.id,
      observation_id: state.currentObservation.observation.id,
      value: options.value
    };
    iNaturalistJS.observation_field_values.update( payload )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}


export function removeObservationFieldValue( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const newOfvs = state.currentObservation.observation.ofvs.map( ofv => (
      ofv.uuid === id ? Object.assign( { }, ofv, { api_status: "deleting" } ) : ofv ) );
    dispatch( updateCurrentObservation( { ofvs: newOfvs } ) );
    iNaturalistJS.observation_field_values.delete( { id } )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
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
