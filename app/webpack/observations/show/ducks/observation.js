import inatjs from "inaturalistjs";
import { fetchObservationPlaces } from "./observation_places";
import { fetchControlledTerms } from "./controlled_terms";
import { fetchMoreFromThisUser } from "./other_observations";
import { fetchQualityMetrics } from "./quality_metrics";

const SET_OBSERVATION = "obs-show/observation/SET_OBSERVATION";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_OBSERVATION:
      return action.observation;
    default:
      // nothing to see here
  }
  return state;
}

export function setObservation( observation ) {
  return {
    type: SET_OBSERVATION,
    observation
  };
}

export function fetchObservation( id, options = { } ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const params = {
      preferred_place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null,
      locale: I18n.locale
    };
    return inatjs.observations.fetch( id, params ).then( response => {
      dispatch( setObservation( response.results[0] ) );
      if ( options.fetchPlaces ) { dispatch( fetchObservationPlaces( ) ); }
      if ( options.fetchControlledTerms ) { dispatch( fetchControlledTerms( ) ); }
      if ( options.fetchQualityMetrics ) { dispatch( fetchQualityMetrics( ) ); }
      if ( options.fetchOtherObservations ) { dispatch( fetchMoreFromThisUser( ) ); }
    } );
  };
}

export function updateObservation( attributes ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = {
      id: observationID,
      ignore_photos: true,
      observation: Object.assign( { }, { id: observationID }, attributes )
    };
    inatjs.observations.update( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function addComment( body ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = {
      parent_type: "Observation",
      parent_id: observationID,
      body
    };
    inatjs.comments.create( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function deleteComment( id ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = { id };
    inatjs.comments.delete( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function addID( taxonID, body ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = {
      observation_id: observationID,
      taxon_id: taxonID,
      body
    };

    inatjs.identifications.create( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function deleteID( id ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = { id };
    inatjs.identifications.delete( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function restoreID( id ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = {
      id,
      current: true
    };

    inatjs.identifications.update( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function fave( ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = { id: observationID };
    inatjs.observations.fave( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function unfave( ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = { id: observationID };
    inatjs.observations.unfave( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function followUser( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser ||
         !state.observation || state.config.currentUser.id === state.observation.user.id ) {
      return;
    }
    const payload = { id: state.config.currentUser.id, friend_id: state.observation.user.id };
    inatjs.users.update( payload ).then( ( ) => {
      console.log( "done" );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function unfollowUser( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser ||
         !state.observation || state.config.currentUser.id === state.observation.user.id ) {
      return;
    }
    const payload = {
      id: state.config.currentUser.id,
      remove_friend_id: state.observation.user.id
    };
    inatjs.users.update( payload ).then( ( ) => {
      console.log( "done" );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function subscribe( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser ||
         !state.observation || state.config.currentUser.id === state.observation.user.id ) {
      return;
    }
    const payload = { id: state.observation.id };
    inatjs.observations.subscribe( payload ).then( ( ) => {
      console.log( "done" );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function addAnnotation( controlledAttributeID, controlledValueID ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = {
      resource_type: "Observation",
      resource_id: observationID,
      controlled_attribute_id: controlledAttributeID,
      controlled_value_id: controlledValueID
    };
    inatjs.annotations.create( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function deleteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = { id };
    inatjs.annotations.delete( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function voteAnnotation( id, vote ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = { id, vote };
    inatjs.annotations.vote( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function unvoteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = { id };
    inatjs.annotations.unvote( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function voteMetric( metric, params = { } ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = Object.assign( { }, { id: observationID, metric }, params );
    inatjs.observations.setQualityMetric( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID, { fetchQualityMetrics: true } ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}

export function unvoteMetric( metric ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = { id: observationID, metric };
    inatjs.observations.deleteQualityMetric( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID, { fetchQualityMetrics: true } ) );
    } ).catch( e => {
      console.log( e );
    } );
  };
}
