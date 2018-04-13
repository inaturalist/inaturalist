import { connect } from "react-redux";
import App from "../components/app";
import { createNewProject } from "../form_reducer";

function mapStateToProps( state ) {
  return {
    config: state.config,
    form: state.form
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    createNewProject: type => { dispatch( createNewProject( type ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
