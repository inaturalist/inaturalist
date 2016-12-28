import { connect } from "react-redux";
import _ from "lodash";
import { stringify } from "querystring";
import { defaultObservationParams } from "../../shared/util";
import RecentObservations from "../components/recent_observations";
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
    showTaxonPhotoModal: ( photo, taxon, observation ) => {
      dispatch( setPhotoModal( photo, taxon, observation ) );
      dispatch( showPhotoModal( ) );
    }
  };
}

const RecentObservationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( RecentObservations );

export default RecentObservationsContainer;
