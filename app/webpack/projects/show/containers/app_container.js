import { connect } from "react-redux";
import App from "../components/app";
import { setSelectedTab, subscribe } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setSelectedTab: tab => { dispatch( setSelectedTab( tab ) ); },
    subscribe: ( ) => { dispatch( subscribe( ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
