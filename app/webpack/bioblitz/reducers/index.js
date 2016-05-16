import _ from "lodash";
import update from "react-addons-update";
import * as types from "../constants/constants";

const defaultState = {
  overallID: NPS_OVERALL_ID,
  umbrellaProjects: NPS_UMBRELLA_PROJECTS,
  umbrellaSubProjects: NPS_UMBRELLA_SUB_PROJECTS,
  allSubProjects: NPS_ALL_SUB_PROJECTS,
  project: NPS_UMBRELLA_PROJECTS[0],
  slideshowUmbrellaIndex: 0,
  slideshowSubProjectIndex: null,
  umbrellaProject: null,
  slideshowIndex: 0,
  colorIndex: 0,
  countColors: 5,
  overallStats: { },
  iconicTaxaCounts: { },
  iconicTaxaSpeciesCounts: { },
  peopleStats: { },
  speciesStats: { },
  // overallProjectSlideshowOrder: [
  //   { slide: ".umbrella-map-slide", duration: 6000 },
  //   { slide: ".iconic-taxa-slide", duration: 6000 },
  //   { slide: ".iconic-taxa-species-slide", duration: 6000 },
  //   { slide: ".people-slide", duration: 6000 },
  //   { slide: ".species-slide", duration: 6000 },
  //   { slide: ".photos-slide", duration: 6000 },
  //   { slide: ".top-projects-slide", duration: 6000 }
  // ],
  // subProjectSlideshowOrder: [
  //   { slide: ".subproject-map-slide", duration: 6000 },
  //   { slide: ".iconic-taxa-slide", duration: 6000 },
  //   { slide: ".iconic-taxa-species-slide", duration: 6000 },
  //   { slide: ".people-slide", duration: 6000 },
  //   { slide: ".species-slide", duration: 6000 },
  //   { slide: ".photos-slide", duration: 6000 }
  // ]
  overallProjectSlideshowOrder: [
    { slide: ".umbrella-map-slide", duration: 15000 },
    { slide: ".iconic-taxa-slide", duration: 20000 },
    { slide: ".iconic-taxa-species-slide", duration: 20000 },
    { slide: ".people-slide", duration: 25000 },
    { slide: ".species-slide", duration: 30000 },
    { slide: ".photos-slide", duration: 25000 },
    { slide: ".top-projects-slide", duration: 30000 }
  ],
  subProjectSlideshowOrder: [
    { slide: ".subproject-map-slide", duration: 15000 },
    { slide: ".iconic-taxa-slide", duration: 20000 },
    { slide: ".iconic-taxa-species-slide", duration: 20000 },
    { slide: ".people-slide", duration: 25000 },
    { slide: ".species-slide", duration: 30000 },
    { slide: ".photos-slide", duration: 20000 }
  ]
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
