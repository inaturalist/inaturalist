import _ from "lodash";
import update from "react-addons-update";
import * as types from "../constants/constants";

// 487 cape cod
// 411 herps of texas
// 6435 death valley

const defaultState = {
  projectID: $( "#app" ).data( "project-id" ) || 6435,
  projectTitle: $( "#app" ).data( "project-title" ) || "Death Valley National Park",
  placeID: $( "#app" ).data( "place-id" ) || 4504,
  overallStats: { },
  iconicTaxaCounts: { },
  iconicTaxaSpeciesCounts: { },
  peopleStats: { },
  speciesStats: { }
};

const bioblitz = ( state = defaultState, action ) => {
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

export default bioblitz;
