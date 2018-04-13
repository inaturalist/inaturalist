import { connect } from "react-redux";
import _ from "lodash";
import PhotoModal from "../../shared/components/photo_modal";
import {
  hidePhotoModal,
  showNext as showNextPhoto,
  showPrev as showPrevPhoto
} from "../../shared/ducks/photo_modal";

function mapStateToProps( state ) {
  const props = {
    photo: state.photoModal.photo,
    taxon: state.photoModal.taxon,
    observation: state.photoModal.observation,
    visible: state.photoModal.visible,
    config: state.config
  };
  if ( state.photoModal.observation ) {
    props.photoLinkUrl = `/observations/${state.photoModal.observation.id}`;
  }
  return props;
}

function mapDispatchToProps( dispatch ) {
  const getPhotos = state => {
    let observationPhotos;
    if ( state.photos.groupedPhotos ) {
      const currentPhoto = state.photoModal.photo;
      const currentGroup = _.find( state.photos.groupedPhotos, group => (
        _.find( group.observationPhotos, op => op.photo.id === currentPhoto.id )
      ) );
      if ( currentGroup ) {
        observationPhotos = currentGroup.observationPhotos;
      }
    } else {
      observationPhotos = state.photos.observationPhotos;
    }
    return observationPhotos.map( op => ( {
      photo: op.photo,
      observation: op.observation,
      taxon: op.observation.taxon,
      user: op.observation.user
    } ) );
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
