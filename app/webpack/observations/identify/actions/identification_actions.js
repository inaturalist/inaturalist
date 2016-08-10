import inatjs from "inaturalistjs";
import {
  loadingDiscussionItem,
  fetchCurrentObservation
} from "./current_observation_actions";
import { fetchObservationsStats } from "./observations_stats_actions";
import { fetchIdentifiers } from "./identifiers_actions";
import { showAlert } from "./alert_actions";

const POST_IDENTIFICATION = "post_identification";

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
    return dispatch(
      postIdentification( { observation_id: observation.id, taxon_id: observation.taxon.id } )
    ).then( ( ) => {
      dispatch( fetchCurrentObservation( observation ) );
      dispatch( fetchObservationsStats( ) );
      dispatch( fetchIdentifiers( ) );
    } );
  };
}

function agreeWithCurrentObservation( ) {
  return function ( dispatch, getState ) {
    return dispatch( agreeWithObservaiton( getState( ).currentObservation.observation ) );
  };
}

export {
  postIdentification,
  POST_IDENTIFICATION,
  agreeWithObservaiton,
  agreeWithCurrentObservation,
  deleteIdentification,
  updateIdentification
};
