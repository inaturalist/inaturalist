import { connect } from "react-redux";
import WebinarBanner from "../components/webinar_banner";
import { updateCurrentUser } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    hideBanner: ( ) => dispatch(
      updateCurrentUser( { prefers_hide_identify_webinar_banner: true } )
    )
  };
}

const WebinarBannerContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( WebinarBanner );

export default WebinarBannerContainer;
