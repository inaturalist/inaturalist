import { connect } from "react-redux";
import Banner from "../components/banner";
import { confirmResendConfirmation } from "../reducers/reducer";

function mapStateToProps( state ) {
  return {
    config: state.config,
    confirmationEmailSent: state.confirmation.confirmationEmailSent
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    confirmResendConfirmation: ( ) => { dispatch( confirmResendConfirmation( ) ); }
  };
}

const BannerContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Banner );

export default BannerContainer;
