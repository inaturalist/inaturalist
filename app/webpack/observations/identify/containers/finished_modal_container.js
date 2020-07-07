import { connect } from "react-redux";
import _ from "lodash";
import FinishedModal from "../components/finished_modal";
import {
  hideFinishedModal,
  updateSearchParams
} from "../actions";

function mapStateToProps( state ) {
  const total = state.observations.totalResults;
  const currentPage = state.searchParams.params.page;
  return {
    reviewed: _.filter(
      state.observations.results,
      o => o.reviewedByCurrentUser
    ).length,
    total,
    pageTotal: state.observations.results.length,
    visible: state.finishedModal.visible,
    currentPage,
    done: ( state.observations.totalPages === currentPage ),
    reviewing: state.observations.reviewing
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideFinishedModal( ) );
    },
    viewMore: ( ) => {
      window.scrollTo( 0, 0 );
      dispatch( hideFinishedModal( ) );
      dispatch( updateSearchParams( { page: 1, force: ( new Date( ) ).getTime( ) } ) );
    },
    loadPage: page => {
      window.scrollTo( 0, 0 );
      dispatch( hideFinishedModal( ) );
      dispatch( updateSearchParams( { page } ) );
    }
  };
}

const FinishedModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FinishedModal );

export default FinishedModalContainer;
