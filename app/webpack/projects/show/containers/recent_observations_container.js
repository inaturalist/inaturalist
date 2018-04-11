import { connect } from "react-redux";
import _ from "lodash";
import { stringify } from "querystring";
import RecentObservations from "../../../taxa/show/components/recent_observations";
import { showPhotoModal, setPhotoModal } from "../../../taxa/shared/ducks/photo_modal";

function mapStateToProps( state ) {
  return {
    observations: state.project.recent_observations_loaded ?
      _.filter( state.project.recent_observations.results, r => r.taxon && r.photos.length > 0 ) : null,
    url: `/observations?${stringify( state.project.search_params )}&place_id=any&verifiable=any`
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showPhotoModal: ( photo, taxon, observation ) => {
      dispatch( setPhotoModal( photo, taxon, observation, { source: "project" } ) );
      dispatch( showPhotoModal( ) );
    }
  };
}

const RecentObservationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( RecentObservations );

export default RecentObservationsContainer;
