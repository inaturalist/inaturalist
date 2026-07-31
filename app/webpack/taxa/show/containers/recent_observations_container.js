import { connect } from "react-redux";
import _ from "lodash";
import { stringify } from "querystring";
import { defaultObservationParams } from "../../shared/util";
import RecentObservations from "../components/recent_observations";
import RecentObservationsLegacy from "../components/recent_observations_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import { showPhotoModal, setPhotoModal } from "../../shared/ducks/photo_modal";

function mapStateToProps( state ) {
  return {
    observations: _.filter( state.observations.recent, o => (
      o.photos.length > 0 && o.photos[0].photoUrl( "small" )
    ) ),
    url: `/observations?${stringify( defaultObservationParams( state ) )}`
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showPhotoModal: ( photo, taxon, observation ) => {
      dispatch( setPhotoModal( photo, taxon, observation, { source: "observations" } ) );
      dispatch( showPhotoModal( ) );
    }
  };
}

const RecentObservationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, RecentObservations, RecentObservationsLegacy ) );

export default RecentObservationsContainer;
