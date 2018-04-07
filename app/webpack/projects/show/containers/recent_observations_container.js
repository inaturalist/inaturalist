import { connect } from "react-redux";
import _ from "lodash";
import { stringify } from "querystring";
import RecentObservations from "../../../taxa/show/components/recent_observations";
import { showPhotoModal, setPhotoModal } from "../../../taxa/shared/ducks/photo_modal";

function mapStateToProps( state ) {
  return {
    observations: state.project.observations_loaded ?
      _.filter( state.project.observations.results, r => r.taxon && r.photos.length > 0 ) : null,
    url: `/observations?${stringify( state.project.search_params )}`
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
