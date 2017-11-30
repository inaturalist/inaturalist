const SET_MEDIA_VIEWER_STATE = "obs-show/media_viewer/SET_MEDIA_VIEWER_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_MEDIA_VIEWER_STATE:
      return Object.assign( { }, state, action.newState );
    default:
      // nothing to see here
  }
  return state;
}

export function setMediaViewerState( newState ) {
  return {
    type: SET_MEDIA_VIEWER_STATE,
    newState
  };
}

export function toggleMediaViewer( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    dispatch( setMediaViewerState( { show: !s.mediaViewer.show } ) );
  };
}
