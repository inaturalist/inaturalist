import { connect } from "react-redux";
import Identifiers from "../components/identifiers";
import { fetchTaxonIdentifiers } from "../ducks/observation";
import { updateSession } from "../ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    observationPlaces: state.observationPlaces,
    identifiers: state.identifications.identifiers,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateSession: params => { dispatch( updateSession( params ) ); },
    fetchTaxonIdentifiers: placeId => { dispatch( fetchTaxonIdentifiers( { placeId } ) ); }
  };
}

const IdentifiersContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Identifiers );

export default IdentifiersContainer;
