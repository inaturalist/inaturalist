import { connect } from "react-redux";
import LicensingModal from "../components/licensing_modal";
import { setLicensingModalState } from "../ducks/licensing_modal";
import { updateObservation } from "../ducks/observation";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    show: state.licensingModal.show,
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); },
    updateObservation: attributes => { dispatch( updateObservation( attributes ) ); },
    setLicensingModalState: ( key, value ) => {
      dispatch( setLicensingModalState( key, value ) );
    }
  };
}

const LicensingModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( LicensingModal );

export default LicensingModalContainer;
