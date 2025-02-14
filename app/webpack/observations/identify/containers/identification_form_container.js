import { connect } from "react-redux";
// import _ from "lodash";
import IdentificationForm from "../components/identification_form";
import {
  onSubmitIdentification
} from "../actions";
import { updateEditorContent } from "../../shared/ducks/text_editors";

// ownProps contains data passed in through the "tag", so in this case
// <IdentificationFormContainer observation={foo} />
function mapStateToProps( state, ownProps ) {
  return {
    config: state.config,
    observation: ownProps.observation,
    currentUser: state.config.currentUser,
    blind: state.config.blind,
    content: state.textEditor.obsIdentifyIdComment
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    onSubmitIdentification: ( identification, options = {} ) => {
      dispatch( onSubmitIdentification( ownProps.observation, identification, options ) );
    },
    updateEditorContent: ( editor, content ) => {
      dispatch( updateEditorContent( editor, content ) );
    }
  };
}

const IdentificationFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentificationForm );

export default IdentificationFormContainer;
