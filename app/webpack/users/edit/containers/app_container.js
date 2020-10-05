import { connect } from "react-redux";

import UserSettings from "../components/app";
// import { setUserData } from "../ducks/profile";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

// function mapDispatchToProps( dispatch ) {
//   return {
//     setUserData: newState => dispatch( setUserData( newState ) )
//   };
// }

const AppContainer = connect(
  mapStateToProps
  // mapDispatchToProps
)( UserSettings );

export default AppContainer;
