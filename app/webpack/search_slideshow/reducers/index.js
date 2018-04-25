import _ from "lodash";
import update from "react-addons-update";
import * as types from "../constants/constants";
/* global SLIDESHOW_PARAMS */
/* global SLIDESHOW_URL_PARAMS */
/* global SLIDESHOW_TITLE */
/* global SLIDESHOW_SUBTITLE */

let defaultParams = { };
if ( typeof SLIDESHOW_PARAMS !== "undefined" ) {
  defaultParams = SLIDESHOW_PARAMS;
} else if ( typeof SLIDESHOW_URL_PARAMS !== "undefined" ) {
  _.each( SLIDESHOW_URL_PARAMS.split( "&" ), kv => {
    const parts = kv.split( "=" );
    defaultParams[parts[0]] = parts[1];
  } );
}

const defaultState = {
  searchParams: defaultParams,
  title: SLIDESHOW_TITLE,
  subtitle: SLIDESHOW_SUBTITLE,
  slideshowIndex: 0,
  overallStats: { },
  peopleStats: { },
  speciesStats: { },
  slideDuration: 2000
};

const reducer = ( state = defaultState, action ) => {
  switch ( action.type ) {

    case types.SET_STATE: {
      let modified = Object.assign( { }, state );
      _.each( action.attrs, ( val, attr ) => {
        modified = update( modified, {
          [attr]: { $set: val }
        } );
      } );
      return modified;
    }

    case types.UPDATE_STATE: {
      let modified = Object.assign( { }, state );
      _.each( action.attrs, ( val, attr ) => {
        modified = update( modified, {
          [attr]: { $merge: val }
        } );
      } );
      return modified;
    }

    default:
      return state;
  }
};

export default reducer;
