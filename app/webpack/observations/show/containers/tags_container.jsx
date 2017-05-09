import { connect } from "react-redux";
import Tags from "../components/tags";
import { addTag, removeTag } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addTag: tag => { dispatch( addTag( tag ) ); },
    removeTag: tag => { dispatch( removeTag( tag ) ); }
  };
}

const TagsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Tags );

export default TagsContainer;
