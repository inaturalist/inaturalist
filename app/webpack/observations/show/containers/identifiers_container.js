import { connect } from "react-redux";
import Identifiers from "../components/identifiers";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    identifiers: state.identifications.identifiers
  };
}

const IdentifiersContainer = connect(
  mapStateToProps
)( Identifiers );

export default IdentifiersContainer;
