import iNaturalistJS from "inaturalistjs";

const SET_MONTH_FREQUENCY = "taxa-show/observations/SET_MONTH_FREQUENCY";
const SET_MONTH_OF_YEAR_FREQUENCY = "taxa-show/observations/SET_MONTH_OF_YEAR_FREQUENCY";
const SET_RECENT_OBSERVATIONS = "taxa-show/observations/SET_RECENT_OBSERVATIONS";
const SET_OBSERVATIONS_COUNT = "taxa-show/observations/SET_OBSERVATIONS_COUNT";
const SET_FIRST_OBSERVATION = "taxa-show/observations/SET_FIRST_OBSERVATION";

export default function reducer(
  state = { monthOfYearFrequency: {}, monthFrequency: {} },
  action
) {
  const newState = Object.assign( {}, state );
  switch ( action.type ) {
    case SET_MONTH_FREQUENCY:
      newState.monthFrequency = Object.assign( newState.monthFrequency, {
        [action.key]: action.frequency
      } );
      break;
    case SET_MONTH_OF_YEAR_FREQUENCY:
      newState.monthOfYearFrequency = Object.assign( newState.monthOfYearFrequency, {
        [action.key]: action.frequency
      } );
      break;
    case SET_RECENT_OBSERVATIONS:
      newState.recent = action.observations;
      break;
    case SET_OBSERVATIONS_COUNT:
      newState.total = action.count;
      break;
    case SET_FIRST_OBSERVATION:
      newState.first = action.observation;
      break;
    default:
      // leave it alone
  }
  return newState;
}

export function setMonthFrequecy( key, frequency ) {
  return {
    type: SET_MONTH_FREQUENCY,
    key,
    frequency
  };
}

export function setMonthOfYearFrequecy( key, frequency ) {
  return {
    type: SET_MONTH_OF_YEAR_FREQUENCY,
    key,
    frequency
  };
}

export function fetchMonthFrequencyVerifiable( taxon ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = taxon || s.taxon.taxon;
    const params = {
      date_field: "observed",
      interval: "month",
      taxon_id: t.id,
      verifiable: true,
      place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null
    };
    return iNaturalistJS.observations.histogram( params ).then( response => {
      dispatch( setMonthFrequecy( "verifiable", response.results.month ) );
    } );
  };
}

export function fetchMonthFrequencyResearchGrade( taxon ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = taxon || s.taxon.taxon;
    const params = {
      date_field: "observed",
      interval: "month",
      taxon_id: t.id,
      quality_grade: "research",
      place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null
    };
    return iNaturalistJS.observations.histogram( params ).then( response => {
      dispatch( setMonthFrequecy( "research", response.results.month ) );
    } );
  };
}

export function fetchMonthFrequency( taxon ) {
  return ( dispatch ) => {
    dispatch( fetchMonthFrequencyVerifiable( taxon ) );
    dispatch( fetchMonthFrequencyResearchGrade( taxon ) );
  };
}

export function fetchMonthOfYearFrequencyVerifiable( taxon ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = taxon || s.taxon.taxon;
    const params = {
      date_field: "observed",
      interval: "month_of_year",
      taxon_id: t.id,
      verifiable: true,
      place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null
    };
    return iNaturalistJS.observations.histogram( params ).then( response => {
      dispatch( setMonthOfYearFrequecy( "verifiable", response.results.month_of_year ) );
    } );
  };
}

export function fetchMonthOfYearFrequencyResearchGrade( taxon ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = taxon || s.taxon.taxon;
    const params = {
      date_field: "observed",
      interval: "month_of_year",
      taxon_id: t.id,
      quality_grade: "research",
      place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null
    };
    return iNaturalistJS.observations.histogram( params ).then( response => {
      dispatch( setMonthOfYearFrequecy( "research", response.results.month_of_year ) );
    } );
  };
}

export function fetchMonthOfYearFrequency( taxon ) {
  return ( dispatch ) => {
    dispatch( fetchMonthOfYearFrequencyVerifiable( taxon ) );
    dispatch( fetchMonthOfYearFrequencyResearchGrade( taxon ) );
  };
}

export function setRecentObservations( observations ) {
  return {
    type: SET_RECENT_OBSERVATIONS,
    observations
  };
}

export function setObservationsCount( count ) {
  return {
    type: SET_OBSERVATIONS_COUNT,
    count
  };
}

export function fetchRecentObservations( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = s.taxon.taxon;
    const p = s.config.preferredPlace;
    const params = {
      taxon_id: t.id,
      place_id: p ? p.id : null
    };
    return ( iNaturalistJS.observations.search( params ).then( response => {
      dispatch( setRecentObservations( response.results ) );
      dispatch( setObservationsCount( response.total_results ) );
    } ) );
  };
}

export function setFirstObservation( observation ) {
  return {
    type: SET_FIRST_OBSERVATION,
    observation
  };
}

export function fetchFirstObservation( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = s.taxon.taxon;
    const p = s.config.preferredPlace;
    const params = {
      taxon_id: t.id,
      place_id: p ? p.id : null,
      order: "asc",
      per_page: 1
    };
    return ( iNaturalistJS.observations.search( params ).then( response => {
      dispatch( setFirstObservation( response.results[0] ) );
    } ) );
  };
}
