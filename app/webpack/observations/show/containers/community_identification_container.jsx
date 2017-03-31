import { connect } from "react-redux";
import CommunityIdentification from "../components/community_identification";
import { addID } from "../ducks/observation";
import { updateObservation } from "../ducks/observation";
import { setCommunityIDModalState } from "../ducks/community_id_modal";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addID: ( taxon, options ) => { dispatch( addID( taxon, options ) ); },
    updateObservation: ( attributes ) => { dispatch( updateObservation( attributes ) ); },
    setCommunityIDModalState: ( key, value ) => {
      dispatch( setCommunityIDModalState( key, value ) );
    }
  };
}

const CommunityIdentificationContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CommunityIdentification );

export default CommunityIdentificationContainer;
