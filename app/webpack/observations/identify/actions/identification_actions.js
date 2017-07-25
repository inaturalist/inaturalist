import inatjs from "inaturalistjs";
import {
  loadingDiscussionItem,
  stopLoadingDiscussionItem,
  fetchCurrentObservation,
  addIdentification
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
    const body = { identification: Object.assign( {}, params ) };
    if ( body.identification.observation ) {
      body.identification.observation_id = body.identification.observation_id || body.identification.observation.id;
      delete body.identification.observation;
    }
    if ( body.identification.taxon ) {
      body.identification.taxon_id = body.identification.taxon_id || body.identification.taxon.id;
      delete body.identification.taxon;
    }
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
    const s = getState( );
    if ( s.config.blind ) {
      return;
    }
    const currentObservation = s.currentObservation.observation;
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

function submitIdentificationWithConfirmation( identification, options = {} ) {
  return dispatch => {
    dispatch( loadingDiscussionItem( identification ) );
    const boundPostIdentification = ( ) => {
      dispatch( postIdentification( identification ) )
      .catch( ( ) => {
        dispatch( stopLoadingDiscussionItem( identification ) );
      } )
      .then( ( ) => {
        dispatch( fetchCurrentObservation( identification.observation ) ).then( ( ) => {
          $( ".ObservationModal:first" ).find( ".sidebar" ).scrollTop( $( window ).height( ) );
        } );
        dispatch( fetchObservationsStats( ) );
        dispatch( fetchIdentifiers( ) );
      } );
    };
    if ( options.confirmationText ) {
      dispatch( showAlert( options.confirmationText, {
        title: I18n.t( "heads_up" ),
        onConfirm: boundPostIdentification,
        onCancel: ( ) => {
          dispatch( stopLoadingDiscussionItem( identification ) );
          dispatch( addIdentification( ) );
        }
      } ) );
    } else {
      boundPostIdentification( );
    }
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
  updateIdentification,
  submitIdentificationWithConfirmation
};
