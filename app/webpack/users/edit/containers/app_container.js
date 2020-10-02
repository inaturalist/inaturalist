import { connect } from "react-redux";
import UserSettings from "../components/app";

function mapStateToProps( state ) {
  return {
    config: state.config
  };
}

// function mapDispatchToProps( dispatch ) {
//   return {
//     // setFlaggingModalState: newState => dispatch( setFlaggingModalState( newState ) )
//   };
// }

const AppContainer = connect(
  mapStateToProps
  // mapDispatchToProps
)( UserSettings );

export default AppContainer;
