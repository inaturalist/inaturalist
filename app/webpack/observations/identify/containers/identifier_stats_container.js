import { connect } from "react-redux";
import IdentifierStats from "../components/identifier_stats";

function mapStateToProps( state ) {
  return state.identifiers;
}

function mapDispatchToProps( ) {
  return { };
}

const IdentifierStatsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentifierStats );

export default IdentifierStatsContainer;
