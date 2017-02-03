import { connect } from "react-redux";
import Tags from "../components/tags";
import { updateObservation } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateObservation: ( attributes ) => { dispatch( updateObservation( attributes ) ); }
  };
}

const TagsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Tags );

export default TagsContainer;
