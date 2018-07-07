import _ from "lodash";
import update from "immutability-helper";
import * as types from "../constants/constants";

const defaultState = {
  /* global SLIDESHOW_PROJECT */
  /* global OVERALL_ID */
  /* global UMBRELLA_PROJECTS */
  /* global UMBRELLA_SUB_PROJECTS */
  /* global ALL_SUB_PROJECTS */
  /* global UMBRELLA_PROJECTS */
  singleProject: SLIDESHOW_PROJECT,
  overallID: ( typeof OVERALL_ID === "undefined" ) ? null :
    OVERALL_ID,
  umbrellaProjects: ( typeof UMBRELLA_PROJECTS === "undefined" ) ? null :
    UMBRELLA_PROJECTS,
  umbrellaSubProjects: ( typeof UMBRELLA_SUB_PROJECTS === "undefined" ) ? null :
    UMBRELLA_SUB_PROJECTS,
  allSubProjects: ( typeof ALL_SUB_PROJECTS === "undefined" ) ? null :
    ALL_SUB_PROJECTS,
  project: SLIDESHOW_PROJECT || UMBRELLA_PROJECTS[0],
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
