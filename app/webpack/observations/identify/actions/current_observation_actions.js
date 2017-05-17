import iNaturalistJS from "inaturalistjs";
import _ from "lodash";
import { setConfig } from "./config_actions";
import { fetchObservationsStats } from "./observations_stats_actions";
import { updateObservationInCollection } from "./observations_actions";
import { showFinishedModal } from "./finished_modal_actions";
import { fetchSuggestions } from "../ducks/suggestions";
import { fetchControlledTerms } from "../../show/ducks/controlled_terms";

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

function fetchCurrentObservation( observation = null ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const obs = observation || s.currentObservation.observation;
    const currentUser = s.config.currentUser;
    const preferredPlace = s.config.preferredPlace;
    const params = {
      preferred_place_id: preferredPlace ? preferredPlace.id : null,
      locale: I18n.locale
    };
    return iNaturalistJS.observations.fetch( [obs.id], params )
      .then( response => {
        const newObs = response.results[0];
        let captiveByCurrentUser = false;
        if ( currentUser && newObs && newObs.quality_metrics ) {
          const userQualityMetric = _.find( newObs.quality_metrics, ( qm ) => (
            qm.user.id === currentUser.id && qm.metric === "wild"
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
          currentUserIdentification = _.find( newObs.identifications, ( ident ) => (
            ident.user.id === currentUser.id && ident.current
          ) );
        }
        newObs.currentUserAgrees = currentUserIdentification &&
          currentUserIdentification.taxon_id === newObs.taxon_id;
        dispatch( updateObservationInCollection( newObs, {
          captiveByCurrentUser,
          reviewedByCurrentUser,
          currentUserAgrees: newObs.currentUserAgrees
        } ) );
        const currentState = getState();
        if (
          currentState.currentObservation.observation &&
          currentState.currentObservation.observation.id === obs.id
        ) {
          dispatch( receiveCurrentObservation( newObs, {
            captiveByCurrentUser,
            reviewedByCurrentUser,
            currentUserIdentification
          } ) );
        }
        return newObs;
      } )
      .then( observation => {
        if ( s.currentObservation.tab === "suggestions" ) {
          dispatch( fetchSuggestions( ) );
        } else if ( s.currentObservation.tab === "annotations" ) {
          dispatch( fetchControlledTerms( { observation } ) );
        }
      } );
  };
}

function showNextObservation( ) {
  return ( dispatch, getState ) => {
    const { observations, currentObservation } = getState();
    let nextObservation;
    if ( currentObservation.visible ) {
      let nextIndex = _.findIndex( observations.results, ( o ) => (
        o.id === currentObservation.observation.id
      ) );
      if ( nextIndex === null || nextIndex === undefined ) { return; }
      nextIndex += 1;
      nextObservation = observations.results[nextIndex];
    } else {
      nextObservation = currentObservation.observation || observations.results[0];
    }
    if ( nextObservation ) {
      dispatch( showCurrentObservation( nextObservation ) );
      dispatch( fetchCurrentObservation( nextObservation ) );
    } else {
      dispatch( hideCurrentObservation( ) );
      dispatch( showFinishedModal( ) );
    }
  };
}

function showPrevObservation( ) {
  return ( dispatch, getState ) => {
    const { observations, currentObservation } = getState();
    if ( !currentObservation.visible ) {
      return;
    }
    let prevIndex = _.findIndex( observations.results, ( o ) => (
      o.id === currentObservation.observation.id
    ) );
    if ( prevIndex === null || prevIndex === undefined ) { return; }
    prevIndex -= 1;
    const prevObservation = observations.results[prevIndex];
    if ( prevObservation ) {
      dispatch( showCurrentObservation( prevObservation ) );
      dispatch( fetchCurrentObservation( prevObservation ) );
    }
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
  return ( dispatch ) => {
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
    const observation = s.currentObservation.observation;
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
    const params = { id: observation.id };
    if (
      s.currentObservation.observation &&
      observation.id === s.currentObservation.observation.id
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
        dispatch( fetchCurrentObservation( observation ) );
        dispatch( fetchObservationsStats( ) );
      } );
    } else {
      iNaturalistJS.observations.review( params ).then( ( ) => {
        dispatch( fetchCurrentObservation( observation ) );
        dispatch( fetchObservationsStats( ) );
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
    // if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newAnnotations = ( state.currentObservation.observation.annotations || [] ).concat( [{
      controlled_attribute: controlledAttribute,
      controlled_value: controlledValue,
      user: state.config.currentUser,
      api_status: "saving"
    }] );
    // dispatch( setAttributes( { annotations: newAnnotations } ) );
    dispatch( updateCurrentObservation( { annotations: newAnnotations } ) );

    const payload = {
      resource_type: "Observation",
      resource_id: state.currentObservation.observation.id,
      controlled_attribute_id: controlledAttribute.id,
      controlled_value_id: controlledValue.id
    };
    // dispatch( callAPI( inatjs.annotations.create, payload ) );
    iNaturalistJS.annotations.create( payload )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}

export function addAnnotationFromKeyboard( attributeLabel, valueLabel ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    if ( !s.currentObservation.observation || s.currentObservation.tab !== "annotations" ) {
      return;
    }
    const attribute = s.controlledTerms.find( a => a.label === attributeLabel );
    if ( !attribute ) { return; }
    const value = attribute.values.find( v => v.label === valueLabel );
    if ( !value ) { return; }
    const existing = s.currentObservation.observation.annotations.find( a => {
      return a.controlled_value && a.controlled_attribute &&
        a.controlled_value.id === value.id &&
        a.controlled_attribute.id === attribute.id;
    } );
    if ( !existing ) {
      dispatch( addAnnotation( attribute, value ) );
    }
  };
}

export function deleteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    // if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newAnnotations = _.map( state.currentObservation.observation.annotations, a => (
      ( a.user.id === state.config.currentUser.id && a.uuid === id ) ?
        Object.assign( { }, a, { api_status: "deleting" } ) : a
    ) );
    // dispatch( setAttributes( { annotations: newAnnotations } ) );
    dispatch( updateCurrentObservation( { annotations: newAnnotations } ) );
    // dispatch( callAPI( inatjs.annotations.delete, { id } ) );
    iNaturalistJS.annotations.delete( { id } )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}

export function voteAnnotation( id, voteValue ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    // if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newAnnotations = _.map( state.currentObservation.observation.annotations, a => (
      ( a.uuid === id ) ?
        Object.assign( { }, a, {
          api_status: "voting",
          votes: ( a.votes || [] ).concat( [{
            vote_flag: ( voteValue !== "bad" ),
            user: state.config.currentUser,
            api_status: "saving"
          }] )
        } ) : a
    ) );
    // dispatch( setAttributes( { annotations: newAnnotations } ) );
    dispatch( updateCurrentObservation( { annotations: newAnnotations } ) );
    // dispatch( callAPI( inatjs.annotations.vote, { id, vote: voteValue } ) );
    iNaturalistJS.annotations.vote( { id, vote: voteValue } )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
  };
}

export function unvoteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    // if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newAnnotations = _.map( state.currentObservation.observation.annotations, a => (
      ( a.uuid === id ) ?
        Object.assign( { }, a, {
          api_status: "voting",
          votes: _.map( a.votes, v => (
            v.user.id === state.config.currentUser.id ?
              Object.assign( { }, v, { api_status: "deleting" } ) : v
          ) )
        } ) : a
    ) );
    // dispatch( setAttributes( { annotations: newAnnotations } ) );
    dispatch( updateCurrentObservation( { annotations: newAnnotations } ) );
    iNaturalistJS.annotations.unvote( { id } )
      .then( () => dispatch( fetchCurrentObservation( ) ) );
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
  showCurrentObservation,
  hideCurrentObservation,
  fetchCurrentObservation,
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
  updateCurrentObservation
};
