import { connect } from "react-redux";
import Taxonomy from "../components/taxonomy";
import { setHoverResult } from "../ducks/computer_vision_eval";

const mapStateToProps = state => ( {
  config: state.config,
  taxa: state.computerVisionEval.obsCard.visionResults.results,
  hoverResult: state.computerVisionEval.hoverResult
} );

const mapDispatchToProps = dispatch => ( {
  setHoverResult: result => {
    dispatch( setHoverResult( result ) );
  }
} );

const TaxonomyContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Taxonomy );

export default TaxonomyContainer;
