import { connect } from "react-redux";
import Profile from "../components/profile";

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
)( Profile );

export default AppContainer;
