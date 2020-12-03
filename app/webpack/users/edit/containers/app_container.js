import { connect } from "react-redux";

import App from "../components/app";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

const AppContainer = connect(
  mapStateToProps
)( App );

export default AppContainer;
