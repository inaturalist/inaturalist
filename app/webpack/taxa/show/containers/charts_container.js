import { connect } from "react-redux";
import Charts from "../components/charts";
import {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency,
  openObservationsSearch
} from "../ducks/observations";

function mapStateToProps( state ) {
  return {
    monthOfYearFrequencyVerifiable: state.observations.monthOfYearFrequency.verifiable,
    monthOfYearFrequencyResearch: state.observations.monthOfYearFrequency.research,
    monthFrequencyVerifiable: state.observations.monthFrequency.verifiable,
    monthFrequencyResearch: state.observations.monthFrequency.research
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchMonthOfYearFrequency: ( ) => dispatch( fetchMonthOfYearFrequency( ) ),
    fetchMonthFrequency: ( ) => dispatch( fetchMonthFrequency( ) ),
    openObservationsSearch: params => dispatch( openObservationsSearch( params ) )
  };
}

const ChartsContainer = connect(
  mapStateToProps,
  mapDispatchToProps,
  null,
  { pure: false }
)( Charts );

export default ChartsContainer;
