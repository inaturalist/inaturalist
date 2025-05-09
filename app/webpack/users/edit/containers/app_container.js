import { connect } from "react-redux";
import { DragDropContext } from "react-dnd";
import HTML5Backend from "react-dnd-html5-backend";

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
)( DragDropContext( HTML5Backend )( App ) );

export default AppContainer;
