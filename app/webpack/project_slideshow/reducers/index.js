import _ from "lodash";
import update from "react-addons-update";
import * as types from "../constants/constants";

const defaultState = {
  /* global SLIDESHOW_PROJECT */
  /* global NPS_OVERALL_ID */
  /* global NPS_UMBRELLA_PROJECTS */
  /* global NPS_UMBRELLA_SUB_PROJECTS */
  /* global NPS_ALL_SUB_PROJECTS */
  /* global NPS_UMBRELLA_PROJECTS */
  singleProject: SLIDESHOW_PROJECT,
  overallID: ( typeof NPS_OVERALL_ID === "undefined" ) ? null :
    NPS_OVERALL_ID,
  umbrellaProjects: ( typeof NPS_UMBRELLA_PROJECTS === "undefined" ) ? null :
    NPS_UMBRELLA_PROJECTS,
  umbrellaSubProjects: ( typeof NPS_UMBRELLA_SUB_PROJECTS === "undefined" ) ? null :
    NPS_UMBRELLA_SUB_PROJECTS,
  allSubProjects: ( typeof NPS_ALL_SUB_PROJECTS === "undefined" ) ? null :
    NPS_ALL_SUB_PROJECTS,
  project: SLIDESHOW_PROJECT || NPS_UMBRELLA_PROJECTS[0],
  slideshowUmbrellaIndex: 0,
  slideshowSubProjectIndex: null,
  umbrellaProject: null,
  slideshowIndex: 0,
  colorIndex: _.random( 4 ),
  slidesShownForUmbrella: 0,
  countColors: 5,
  overallStats: { },
  iconicTaxaCounts: { },
  iconicTaxaSpeciesCounts: { },
  peopleStats: { },
  speciesStats: { },
  overallProjectSlideshowOrder: [
    { slide: ".umbrella-map-slide", duration: 15000 },
    { slide: ".iconic-taxa-slide", duration: 15000 },
    { slide: ".iconic-taxa-species-slide", duration: 15000 },
    { slide: ".people-slide", duration: 20000 },
    { slide: ".species-slide", duration: 25000 },
    { slide: ".photos-slide", duration: 25000 },
    { slide: ".top-projects-slide", duration: 20000 }
  ],
  subProjectSlideshowOrder: [
    { slide: ".subproject-map-slide", duration: 15000 },
    { slide: ".iconic-taxa-slide", duration: 15000 },
    { slide: ".iconic-taxa-species-slide", duration: 15000 },
    { slide: ".people-slide", duration: 20000 },
    { slide: ".species-slide", duration: 25000 },
    { slide: ".photos-slide", duration: 25000 }
  ]
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
