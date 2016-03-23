import { connect } from "react-redux";
import SearchBar from "../components/search_bar";
import { fetchObservations, updateSearchParams } from "../actions";

function mapStateToProps( state ) {
  return {
    // observation: state.currentObservation.observation,
    // visible: state.currentObservation.visible
    params: state.searchParams
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateSearchParams: ( params ) => {
      dispatch( updateSearchParams( params ) );
      dispatch( fetchObservations( ) );
    }
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SearchBar );

export default ObservationModalContainer;
