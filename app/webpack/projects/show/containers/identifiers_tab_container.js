import { connect } from "react-redux";
import IdentifiersTab from "../components/identifiers_tab";
import { setConfig } from "../../../shared/ducks/config";
import { fetchIdentifiers } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    identifiers: state.project.identifiers ? state.project.identifiers.results : null,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); },
    fetchIdentifiers: ( ) => { dispatch( fetchIdentifiers( true ) ); }
  };
}

const IdentifiersTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentifiersTab );

export default IdentifiersTabContainer;
