import { connect } from "react-redux";
import Tags from "../components/tags";
import { addTag, removeTag } from "../ducks/observation";
import { updateSession } from "../ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addTag: tag => { dispatch( addTag( tag ) ); },
    removeTag: tag => { dispatch( removeTag( tag ) ); },
    updateSession: params => { dispatch( updateSession( params ) ); }
  };
}

const TagsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Tags );

export default TagsContainer;
