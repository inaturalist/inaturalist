import fetch from "cross-fetch";
import { setConfig } from "../../../shared/ducks/config";

const SET_TAXA = "geo-model/index/SET_TAXA";

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case SET_TAXA: {
      return action.taxa;
    }
    default:
  }
  return state;
}

export function setTaxa( taxa ) {
  return {
    type: SET_TAXA,
    taxa
  };
}

export function resetStates( ) {
  return dispatch => {
    dispatch( setTaxa( [] ) );
  };
}

const thenCheckStatus = response => {
  if ( response.status >= 200 && response.status < 300 ) {
    return response;
  }
  const error = new Error( response.statusText );
  error.response = response;
  throw error;
};

const thenText = response => ( response.text( ) );

const thenJson = text => {
  if ( text ) { return JSON.parse( text ); }
  return text;
};

export function fetchTaxa( ) {
  return function ( dispatch, getState ) {
    const { config } = getState( );
    fetch( `/geo_model.json?order_by=${config.orderBy}&order=${config.order}` )
      .then( thenCheckStatus )
      .then( thenText )
      .then( thenJson )
      .then( r => {
        dispatch( setTaxa( r ) );
      } )
      .catch( e => {
        console.log( ["error", e] ); // eslint-disable-line no-console
      } );
  };
}

export function setOrderBy( orderBy, defaultOrder ) {
  return function ( dispatch, getState ) {
    const { config } = getState( );
    let sortOrder;
    if ( orderBy !== config.orderBy ) {
      sortOrder = defaultOrder;
    } else {
      sortOrder = config.order === "asc" ? "desc" : "asc";
    }
    dispatch( setConfig( { orderBy, order: sortOrder } ) );
    dispatch( fetchTaxa( ) );
  };
}
