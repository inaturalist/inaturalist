import { connect } from "react-redux";
import Taxonomy from "../components/taxonomy";
import { setHoverResult, updateUserSetting } from "../ducks/computer_vision_eval";

const mapStateToProps = state => ( {
  config: state.config,
  taxa: state.computerVisionEval.filteredResults,
  toggleableSettings: state.computerVisionEval.toggleableSettings,
  hoverResult: state.computerVisionEval.hoverResult
} );

const mapDispatchToProps = dispatch => ( {
  setHoverResult: result => {
    dispatch( setHoverResult( result ) );
  },
  updateUserSetting: ( setting, value ) => {
    dispatch( updateUserSetting( setting, value ) );
  }
} );

const TaxonomyContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Taxonomy );

export default TaxonomyContainer;
