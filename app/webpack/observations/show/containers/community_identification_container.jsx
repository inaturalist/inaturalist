import { connect } from "react-redux";
import CommunityIdentification from "../components/community_identification";
import { addID, updateObservation } from "../ducks/observation";
import { setCommunityIDModalState } from "../ducks/community_id_modal";
import { updateSession } from "../ducks/users";
import {
  fetchSuggestions,
  updateWithObservation as updateSuggestionsWithObservation
} from "../../identify/ducks/suggestions";
import {
  showCurrentObservation as showObservationModal
} from "../../identify/actions/current_observation_actions";

function mapStateToProps( state ) {
  return {
    observation: Object.assign( {}, state.observation, { places: state.observationPlaces } ),
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addID: ( taxon, options ) => { dispatch( addID( taxon, options ) ); },
    updateObservation: attributes => { dispatch( updateObservation( attributes ) ); },
    setCommunityIDModalState: ( key, value ) => {
      dispatch( setCommunityIDModalState( key, value ) );
    },
    updateSession: params => { dispatch( updateSession( params ) ); },
    onClickCompare: ( e, taxon, observation ) => {
      const newObs = Object.assign( {}, observation, { taxon } );
      dispatch( updateSuggestionsWithObservation( newObs ) );
      dispatch( fetchSuggestions( ) );
      dispatch( showObservationModal( observation ) );
      e.preventDefault( );
      return false;
    }
  };
}

const CommunityIdentificationContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CommunityIdentification );

export default CommunityIdentificationContainer;
