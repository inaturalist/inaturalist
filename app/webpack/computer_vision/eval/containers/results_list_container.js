import { connect } from "react-redux";
import ResultsList from "../components/results_list";
import { setHoverResult } from "../ducks/computer_vision_eval";

const mapStateToProps = state => ( {
  config: state.config,
  commonAncestor: state.computerVisionEval.obsCard.visionResults.common_ancestor,
  taxa: state.computerVisionEval.obsCard.visionResults.results,
  hoverResult: state.computerVisionEval.hoverResult
} );

const mapDispatchToProps = dispatch => ( {
  setHoverResult: result => {
    dispatch( setHoverResult( result ) );
  }
} );

const ResultsListContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ResultsList );

export default ResultsListContainer;
