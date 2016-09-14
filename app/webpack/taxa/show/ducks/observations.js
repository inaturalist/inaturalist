import iNaturalistJS from "inaturalistjs";

const SET_MONTH_FREQUENCY = "taxa-show/observations/SET_MONTH_FREQUENCY";
const SET_MONTH_OF_YEAR_FREQUENCY = "taxa-show/observations/SET_MONTH_OF_YEAR_FREQUENCY";

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
  return ( dispatch ) => {
    const params = {
      date_field: "observed",
      interval: "month",
      taxon_id: taxon.id,
      verifiable: true
    };
    return iNaturalistJS.observations.histogram( params ).then( response => {
      dispatch( setMonthFrequecy( "verifiable", response.results.month ) );
    } );
  };
}

export function fetchMonthFrequencyResearchGrade( taxon ) {
  return ( dispatch ) => {
    const params = {
      date_field: "observed",
      interval: "month",
      taxon_id: taxon.id,
      quality_grade: "research"
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
  return ( dispatch ) => {
    const params = {
      date_field: "observed",
      interval: "month_of_year",
      taxon_id: taxon.id,
      verifiable: true
    };
    return iNaturalistJS.observations.histogram( params ).then( response => {
      dispatch( setMonthOfYearFrequecy( "verifiable", response.results.month_of_year ) );
    } );
  };
}

export function fetchMonthOfYearFrequencyResearchGrade( taxon ) {
  return ( dispatch ) => {
    const params = {
      date_field: "observed",
      interval: "month_of_year",
      taxon_id: taxon.id,
      quality_grade: "research"
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
