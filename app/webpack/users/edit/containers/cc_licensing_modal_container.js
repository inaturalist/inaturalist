import { connect } from "react-redux";
import CreativeCommonsLicensingModal from "../components/cc_licensing_modal";
import { hideModal } from "../ducks/cc_licensing_modal";

function mapStateToProps( state ) {
  return {
    show: state.creativeCommonsLicensing.show
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => { dispatch( hideModal( ) ); }
  };
}

const CreativeCommonsLicensingModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CreativeCommonsLicensingModal );

export default CreativeCommonsLicensingModalContainer;
