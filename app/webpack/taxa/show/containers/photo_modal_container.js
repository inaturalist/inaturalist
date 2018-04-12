import { connect } from "react-redux";
import _ from "lodash";
import PhotoModal from "../../shared/components/photo_modal";
import {
  hidePhotoModal,
  showNext as showNextPhoto,
  showPrev as showPrevPhoto
} from "../../shared/ducks/photo_modal";

function mapStateToProps( state ) {
  const newState = {
    photo: state.photoModal.photo,
    taxon: state.photoModal.taxon,
    observation: state.photoModal.observation,
    visible: state.photoModal.visible,
    config: state.config
  };
  if ( state.taxon && state.taxon.taxon && state.photoModal.taxon &&
    state.taxon.taxon.id === state.photoModal.taxon.id
  ) {
    newState.linkToTaxon = false;
  }
  if ( state.photoModal.observation ) {
    newState.photoLinkUrl = `/observations/${state.photoModal.observation.id}`;
  } else if ( state.photoModal.photo ) {
    newState.photoLinkUrl = `/photos/${state.photoModal.photo.id}`;
  }
  return newState;
}

function mapDispatchToProps( dispatch ) {
  const getPhotos = state => {
    if ( state.photoModal.options.source === "observations" ) {
      const observations = _.filter( state.observations.recent, o => (
        o.photos.length > 0 && o.photos[0].photoUrl( "small" )
      ) );
      return observations.map( o => ( {
        observation: o,
        photo: o.photos[0],
        taxon: o.taxon,
        options: { source: "observations" }
      } ) );
    }
    if ( state.photoModal.options.source === "project" ) {
      const observations = _.filter( state.project.recent_observations.results, o => (
        o.photos.length > 0 && o.photos[0].photoUrl( "small" )
      ) );
      return observations.map( o => ( {
        observation: o,
        photo: o.photos[0],
        taxon: o.taxon,
        options: { source: "project" }
      } ) );
    }
    return state.taxon.taxonPhotos;
  };
  return {
    showNext: ( ) => {
      dispatch( showNextPhoto( getPhotos ) );
    },
    showPrev: ( ) => {
      dispatch( showPrevPhoto( getPhotos ) );
    },
    onClose: ( ) => dispatch( hidePhotoModal( ) )
  };
}

const PhotoModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoModal );

export default PhotoModalContainer;
