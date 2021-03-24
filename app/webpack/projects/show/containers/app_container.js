import { connect } from "react-redux";
import App from "../components/app";
import {
  setSelectedTab,
  leave,
  convertProject,
  fetchQualityGradeCounts
} from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    convertProject: ( ) => dispatch( convertProject( ) ),
    setSelectedTab: tab => dispatch( setSelectedTab( tab ) ),
    leave: ( ) => dispatch( leave( ) ),
    fetchQualityGradeCounts: ( ) => dispatch( fetchQualityGradeCounts( ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
