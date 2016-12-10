import { connect } from "react-redux";
import Charts from "../components/charts";
import {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency,
  openObservationsSearch
} from "../ducks/observations";

function mapStateToProps( state ) {
  return {
    monthOfYearFrequency: state.observations.monthOfYearFrequency,
    monthFrequency: state.observations.monthFrequency
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
