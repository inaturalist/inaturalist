import { connect } from "react-redux";
import PaginationControl from "../components/pagination_control";
import {
  fetchObservations,
  updateSearchParams
} from "../actions";

function mapStateToProps( state ) {
  return {
    visible: !state.searchParams.params.reviewed,
    totalResults: state.observations.totalResults,
    current: state.searchParams.params.page,
    perPage: state.searchParams.params.per_page
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    loadMore: ( ) => {
      dispatch( updateSearchParams( { page: 1 } ) );
      dispatch( fetchObservations( ) );
    },
    loadPage: ( page ) => {
      dispatch( updateSearchParams( { page } ) );
      dispatch( fetchObservations( ) );
    }
  };
}

const PaginationControlContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PaginationControl );

export default PaginationControlContainer;
