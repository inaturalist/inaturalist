import iNaturalistJS from "inaturalistjs";
import _ from "lodash";
import { fetchObservationsStats } from "./observations_stats_actions";
import { updateObservationInCollection } from "./observations_actions";

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

function updateCurrentObservation( observation, updates ) {
  return Object.assign( { }, {
    type: UPDATE_CURRENT_OBSERVATION,
    observation,
    updates
  } );
}

function fetchCurrentObservation( observation = null ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const obs = observation || s.currentObservation.observation;
    const currentUser = s.config.currentUser;
    return iNaturalistJS.observations.fetch( [obs.id] )
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
          reviewedByCurrentUser
        } ) );
        const currentState = getState();
        if (
          currentState.currentObservation.observation &&
          currentState.currentObservation.observation.id === obs.id
        ) {
          dispatch(
            receiveCurrentObservation( newObs, {
              captiveByCurrentUser,
              reviewedByCurrentUser,
              currentUserIdentification
            } )
          );
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
    dispatch( updateCurrentObservation( observation, {
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
      dispatch( updateCurrentObservation( observation, {
        reviewedByCurrentUser: !reviewed
      } ) );
    }
    dispatch( updateObservationInCollection( observation, {
      reviewedByCurrentUser: !reviewed
    } ) );
    if ( reviewed ) {
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

function loadingDiscussionItem( ) {
  return { type: LOADING_DISCUSSION_ITEM };
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
  updateCurrentObservation
};
