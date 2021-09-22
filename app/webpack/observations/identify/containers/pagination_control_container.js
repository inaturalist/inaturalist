import { connect } from "react-redux";
import PaginationControl from "../components/pagination_control";
import { updateSearchParams } from "../actions";

function mapStateToProps( state ) {
  return {
    loadMoreVisible: !state.searchParams.params.reviewed,
    paginationVisible: state.searchParams.params.order_by !== "random",
    totalResults: state.observations.totalResults,
    current: state.searchParams.params.page,
    perPage: state.searchParams.params.per_page,
    reviewing: state.observations.reviewing
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    loadMore: ( ) => {
      window.scrollTo( 0, 0 ); // $.scrollTo didn't seem to work for some reason
      dispatch( updateSearchParams( { page: 1, force: ( new Date( ) ).getTime( ) } ) );
    },
    loadPage: page => {
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
