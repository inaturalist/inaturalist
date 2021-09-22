import { connect } from "react-redux";
import ThirdPartyTrackingModal from "../components/third_party_tracking_modal";
import { setModalState } from "../ducks/third_party_tracking_modal";

function mapStateToProps( state ) {
  return {
    show: state.thirdPartyTracking.show
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => { dispatch( setModalState( { show: false } ) ); }
  };
}

const ThirdPartyTrackingModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ThirdPartyTrackingModal );

export default ThirdPartyTrackingModalContainer;
