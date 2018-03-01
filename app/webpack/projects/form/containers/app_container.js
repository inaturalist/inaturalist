import { connect } from "react-redux";
import App from "../components/app";
import { setProject } from "../form_reducer";

function mapStateToProps( state ) {
  return {
    config: state.config,
    form: state.form
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setProject: project => { dispatch( setProject( project ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
