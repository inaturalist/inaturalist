import { connect } from "react-redux";
import PaginationControl from "../components/pagination_control";
import { updateSearchParams } from "../actions";

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
      window.scrollTo( 0, 0 ); // $.scrollTo didn't seem to work for some reason
      dispatch( updateSearchParams( { page: 1 } ) );
    },
    loadPage: ( page ) => {
      window.scrollTo( 0, 0 );
      dispatch( updateSearchParams( { page } ) );
    }
  };
}

const PaginationControlContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PaginationControl );

export default PaginationControlContainer;
