import { connect } from "react-redux";

import App from "../components/app";
import { setSelectedSectionFromMenu } from "../ducks/app_sections";

function mapStateToProps( state ) {
  return {
    profile: state.profile,
    section: state.section.section
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setContainerIndex: index => dispatch( setSelectedSectionFromMenu( index ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
