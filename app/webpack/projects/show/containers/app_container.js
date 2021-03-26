import { connect } from "react-redux";
import App from "../components/app";
import {
  setSelectedTab,
  leave,
  convertProject,
  fetchSpeciesObservers,
  fetchSpecies,
  fetchRecentObservations,
  fetchIdentifiers
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
    fetchSpeciesObservers: ( ) => dispatch( fetchSpeciesObservers( ) ),
    fetchSpecies: ( ) => { dispatch( fetchSpecies( true ) ); },
    fetchRecentObservations: ( ) => { dispatch( fetchRecentObservations( true ) ); },
    fetchIdentifiers: ( ) => { dispatch( fetchIdentifiers( true ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
