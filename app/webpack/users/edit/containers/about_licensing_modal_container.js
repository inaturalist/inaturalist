import { connect } from "react-redux";
import AboutLicensingModal from "../components/about_licensing_modal";
import { hideModal } from "../ducks/about_licensing_modal";

function mapStateToProps( state ) {
  return {
    show: state.aboutLicensing.show
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => { dispatch( hideModal( ) ); }
  };
}

const AboutLicensingModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( AboutLicensingModal );

export default AboutLicensingModalContainer;
