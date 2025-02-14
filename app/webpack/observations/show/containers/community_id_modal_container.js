import { connect } from "react-redux";
import CommunityIDModal from "../components/community_id_modal";
import { setCommunityIDModalState } from "../ducks/community_id_modal";
import { performOrOpenConfirmationModal } from "../../../shared/ducks/user_confirmation";

function mapStateToProps( state ) {
  return {
    show: state.communityIDModal.show,
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setCommunityIDModalState: ( key, value ) => {
      dispatch( setCommunityIDModalState( key, value ) );
    },
    performOrOpenConfirmationModal: ( method, options = { } ) => (
      dispatch( performOrOpenConfirmationModal( method, options ) )
    )
  };
}

const CommunityIDModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CommunityIDModal );

export default CommunityIDModalContainer;
