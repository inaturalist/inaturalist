import { connect } from "react-redux";
import IdentifiersTab from "../components/identifiers_tab";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    config: state.config,
    identifiers: state.project.identifiers ? state.project.identifiers.results : null
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); }
  };
}

const IdentifiersTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentifiersTab );

export default IdentifiersTabContainer;
