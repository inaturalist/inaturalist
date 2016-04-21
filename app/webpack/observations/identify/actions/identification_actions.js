import inatjs from "inaturalistjs";
import {
  loadingDiscussionItem,
  fetchCurrentObservation
} from "./current_observation_actions";
import { fetchObservationsStats } from "./observations_stats_actions";

const POST_IDENTIFICATION = "post_identification";

function postIdentification( params ) {
  return function ( dispatch ) {
    const body = Object.assign( {}, params );
    body.user_id = 1;
    return inatjs.identifications.create( body )
      .then( response => {
        dispatch( fetchObservationsStats( ) );
        return response;
      } );
  };
}

function agreeWithCurrentObservation( ) {
  return function ( dispatch, getState ) {
    const o = getState( ).currentObservation.observation;
    dispatch( loadingDiscussionItem( ) );
    return dispatch(
      postIdentification( { observation_id: o.id, taxon_id: o.taxon.id } )
    ).then( ( ) => {
      dispatch( fetchCurrentObservation( o ) );
    } );
  };
}

export {
  postIdentification,
  POST_IDENTIFICATION,
  agreeWithCurrentObservation
};
