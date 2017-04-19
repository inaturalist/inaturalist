import _ from "lodash";
import fetch from "isomorphic-fetch";
import moment from "moment-timezone";
import update from "react-addons-update";
import DroppedFile from "../../observations/uploader/models/dropped_file";
import ObsCard from "../../observations/uploader/models/obs_card";

const RESET_STATE = "computer_vision_demo/RESET_STATE";
const SET_LOCATION_CHOOSER = "computer_vision_demo/SET_LOCATION_CHOOSER";
const SET_OBS_CARD = "computer_vision_demo/SET_OBS_CARD";
const UPDATE_STATE = "computer_vision_demo/UPDATE_STATE";
const UPDATE_OBS_CARD = "computer_vision_demo/UPDATE_OBS_CARD";

const DEFAULT_STATE = { obsCard: { uploadedFile: { } } };

export default function reducer( state = DEFAULT_STATE, action ) {
  let modified;
  switch ( action.type ) {
    case RESET_STATE:
      window.scrollTo( 0, 0 );
      return Object.assign( { }, DEFAULT_STATE );
    case SET_LOCATION_CHOOSER:
      return Object.assign( { }, state, { locationChooser: action.attrs } );
    case SET_OBS_CARD:
      return Object.assign( { }, state, { obsCard: action.obsCard } );
    case UPDATE_STATE:
      modified = Object.assign( { }, state );
      _.each( action.newState, ( val, attr ) => {
        modified = update( modified, {
          [attr]: { $merge: val }
        } );
      } );
      return modified;
    case UPDATE_OBS_CARD:
      return Object.assign( { }, state, { obsCard:
        Object.assign( { }, state.obsCard, action.obsCard ) } );
    default:
  }
  return state;
}

export function resetState( ) {
  return { type: RESET_STATE };
}

export function setObsCard( obsCard ) {
  return {
    type: SET_OBS_CARD,
    obsCard
  };
}

export function updateState( newState ) {
  return {
    type: UPDATE_STATE,
    newState
  };
}
export function setLocationChooser( attrs ) {
  return {
    type: SET_LOCATION_CHOOSER,
    attrs
  };
}

export function updateObsCard( obsCard ) {
  return {
    type: UPDATE_OBS_CARD,
    obsCard
  };
}

export function readFileExif( file ) {
  return function ( dispatch ) {
    file.readExif( ).then( metadata => {
      dispatch( updateObsCard( metadata ) );
    } );
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

export function score( obsCard ) {
  return function ( dispatch ) {
    dispatch( updateObsCard( { visionStatus: "loading" } ) );
    const params = { };
    const pageQuerystring = decodeURIComponent( window.location.search.substring( 1 ) );
    if ( !_.isEmpty( pageQuerystring ) ) {
      _.each( pageQuerystring.split( "&" ), kv => {
        const parts = kv.split( "=" );
        params[parts[0]] = parts[1];
      } );
    }
    if ( obsCard.selected_date ) {
      params.date = moment( obsCard.selected_date, "YYYY/MM/DD" ).format( );
    }
    if ( obsCard.selected_taxon ) {
      params.taxon_id = obsCard.selected_taxon.id;
    }
    if ( obsCard.latitude && obsCard.longitude ) {
      params.lat = obsCard.latitude;
      params.lng = obsCard.longitude;
    }
    let fetchURL = `/computer_vision_demo_uploads/${obsCard.uploadedFile.photo.uuid}/score`;
    if ( !_.isEmpty( params ) ) {
      fetchURL += `?${$.param( params )}`;
    }
    fetch( fetchURL, { credentials: "same-origin" } ).
      then( thenCheckStatus ).
      then( thenText ).
      then( thenJson ).
      then( r => {
        dispatch( updateObsCard( { visionResults: r, visionStatus: null } ) );
      } ).catch( e => {
        console.log( ["error", e] );
      }
    );
  };
}

export function uploadImage( obsCard ) {
  return function ( dispatch ) {
    const headers = { };
    const csrfParam = $( "meta[name=csrf-param]" ).attr( "content" );
    const csrfToken = $( "meta[name=csrf-token]" ).attr( "content" );
    headers[csrfParam] = csrfToken;
    const body = new FormData( );
    body.append( "file", obsCard.uploadedFile.file );
    const fetchOpts = {
      method: "post",
      credentials: "same-origin",
      headers,
      body
    };
    fetch( "/computer_vision_demo_uploads", fetchOpts ).
      then( thenCheckStatus ).
      then( thenText ).
      then( thenJson ).
      then( r => {
        const serverMetadata = obsCard.uploadedFile.additionalPhotoMetadata( r );
        dispatch( updateObsCard( { uploadedFile: Object.assign( { }, obsCard.uploadedFile, {
          uploadState: "uploaded", photo: r, serverMetadata } ) } ) );
      } ).catch( e => {
        dispatch( updateObsCard( { uploadedFile:
          Object.assign( { }, obsCard.uploadedFile, { uploadState: "failed" } ) } ) );
        console.log( ["error", e] );
      }
    );
  };
}

export function onFileDrop( droppedFiles ) {
  return dispatch => {
    if ( droppedFiles.length === 0 ) { return; }
    dispatch( resetState( ) );
    let done;
    droppedFiles.forEach( f => {
      if ( done ) { return; }
      if ( f.type.match( /^image\// ) ) {
        done = true;
        const obsCard = new ObsCard( );
        obsCard.uploadedFile = DroppedFile.fromFile( f );
        dispatch( setObsCard( obsCard ) );
        dispatch( readFileExif( obsCard.uploadedFile ) );
        dispatch( uploadImage( obsCard ) );
      }
    } );
  };
}

