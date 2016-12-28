import inatjs from "inaturalistjs";
import {
  loadingDiscussionItem,
  fetchCurrentObservation
} from "./current_observation_actions";
import { fetchObservationsStats } from "./observations_stats_actions";
import { updateObservationInCollection } from "./observations_actions";
import { fetchIdentifiers } from "./identifiers_actions";
import { showAlert } from "./alert_actions";

const POST_IDENTIFICATION = "post_identification";
const AGREEING_WITH_OBSERVATION = "agreeing_with_observation";
const STOP_AGREEING_WITH_OBSERVATION = "stop_agreeing_with_observation";

function postIdentification( params ) {
  return function ( dispatch ) {
    const body = Object.assign( {}, params );
    body.user_id = 1;
    return inatjs.identifications.create( body ).catch( e => {
      dispatch( showAlert(
        I18n.t( "failed_to_save_record" ),
        { title: I18n.t( "request_failed" ) }
      ) );
      throw e;
    } );
  };
}

function deleteIdentification( ident ) {
  return function ( ) {
    return inatjs.identifications.delete( ident );
  };
}

function updateIdentification( ident, updates ) {
  return function ( ) {
    return inatjs.identifications.update( ident, updates );
  };
}

function agreeWithObservaiton( observation ) {
  return function ( dispatch ) {
    dispatch( loadingDiscussionItem( ) );
    dispatch( updateObservationInCollection( observation, { agreeLoading: true } ) );
    return dispatch(
      postIdentification( { observation_id: observation.id, taxon_id: observation.taxon.id } )
    ).then( ( ) => {
      dispatch( updateObservationInCollection( observation, { agreeLoading: false } ) );
      dispatch( fetchCurrentObservation( observation ) );
      dispatch( fetchObservationsStats( ) );
      dispatch( fetchIdentifiers( ) );
    } );
  };
}

function agreeingWithObservation( ) {
  return { type: AGREEING_WITH_OBSERVATION };
}

function stopAgreeingWithObservation( ) {
  return { type: STOP_AGREEING_WITH_OBSERVATION };
}

function agreeWithCurrentObservation( ) {
  return function ( dispatch, getState ) {
    const currentObservation = getState( ).currentObservation.observation;
    if ( !currentObservation || !currentObservation.id || !currentObservation.taxon ) {
      return null;
    }
    dispatch( agreeingWithObservation( ) );
    return dispatch(
      agreeWithObservaiton( currentObservation )
    ).then( ( ) => {
      dispatch( stopAgreeingWithObservation( ) );
    } );
  };
}

export {
  POST_IDENTIFICATION,
  AGREEING_WITH_OBSERVATION,
  STOP_AGREEING_WITH_OBSERVATION,
  postIdentification,
  agreeWithObservaiton,
  agreeWithCurrentObservation,
  deleteIdentification,
  agreeingWithObservation,
  stopAgreeingWithObservation,
  updateIdentification
};
