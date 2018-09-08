import { fetch } from "../../../shared/util";

const START_LOADING = "observations-uploader/saved_locations/START_LOADING";
const SET_SAVED_LOCATIONS = "observations-uploader/saved_locations/set_saved_locations";

export default function reducer(
  state = {
    loading: false,
    savedLocations: []
  },
  action
) {
  const newState = Object.assign( {}, state );
  switch ( action.type ) {
    case START_LOADING:
      newState.loading = true;
      break;
    case SET_SAVED_LOCATIONS:
      newState.loading = false;
      newState.savedLocations = action.savedLocations;
      break;
    default:
      // Nothing to see here
  }
  return newState;
}

const startLoading = ( ) => ( { type: START_LOADING } );

const setSavedLocations = savedLocations => ( {
  type: SET_SAVED_LOCATIONS,
  savedLocations
} );

export function fetchSavedLocations( ) {
  return function ( dispatch ) {
    dispatch( startLoading( ) );
    const authenticityToken = $( "meta[name=csrf-token]" ).attr( "content" );
    fetch( `/saved_locations.json?authenticity_token=${authenticityToken}` )
      .then( response => response.json( ) )
      .then( savedLocations => {
        dispatch( setSavedLocations( savedLocations ) );
      } )
      .catch( e => console.log( "Failed to fetch saved locations: ", e ) );
  };
}

export function createSavedLocation( params ) {
  return function ( dispatch ) {
    const data = new FormData( );
    for ( const key in params ) {
      if ( key ) {
        data.append( `saved_location[${key}]`, params[key] );
      }
    }
    data.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
    fetch( "/saved_locations.json", {
      method: "POST",
      body: data
    } ).then( response => {
      if ( response.status < 400 ) {
        dispatch( fetchSavedLocations( ) );
      } else {
        response.json( ).then( json => {
          let errorText = "Could not save location";
          for ( const k in json ) {
            if ( k ) {
              errorText += `\n${json[k].map( error => `${k} ${error}` ).join( "\n" )}`;
            }
          }
          alert( errorText );
        } );
      }
    } ).catch( e => {
      alert( I18n.t( "doh_something_went_wrong_error", { error: e.message } ) );
    } );
  };
}

export function removeSavedLocation( savedLocation ) {
  return function ( dispatch ) {
    const url = `/saved_locations/${savedLocation.id}.json`;
    const data = new FormData( );
    data.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
    fetch( url, { method: "DELETE", body: data } ).then( ( ) => {
      dispatch( fetchSavedLocations( ) );
    } ).catch( e => {
      alert( I18n.t( "doh_something_went_wrong_error", { error: e.message } ) );
    } );
  };
}
