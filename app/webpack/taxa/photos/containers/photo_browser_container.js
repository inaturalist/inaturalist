import { connect } from "react-redux";
import _ from "lodash";
import PhotoBrowser from "../components/photo_browser";
import { showPhotoModal, setPhotoModal } from "../../shared/ducks/photo_modal";
import {
  fetchMorePhotos,
  updateObservationParamsAndUrl,
  setGrouping,
  reloadPhotos,
  setConfigAndUrl
} from "../ducks/photos";

function mapStateToProps( state ) {
  const props = {
    hasMorePhotos: false,
    layout: state.config.layout,
    grouping: state.config.grouping,
    groupedPhotos: state.photos.groupedPhotos,
    params: state.photos.observationParams
  };
  props.terms = state.taxon.terms.map( term => {
    const newTerm = Object.assign( { }, term );
    const paramName = `field:${term.name}`;
    const param = _.find( state.photos.observationParams, ( v, k ) => ( k === paramName ) );
    if ( param ) {
      newTerm.selectedValue = state.photos.observationParams[paramName];
    }
    return newTerm;
  } );
  if ( state.photos.observationPhotos && state.photos.observationPhotos.length > 0 ) {
    let observationPhotos = [];
    if ( state.taxon.taxon.rank_level <= 10 ) {
      // For species and lower, show all photos
      observationPhotos = state.photos.observationPhotos;
    } else {
      // For taxa above species, show one photo per observation
      const obsPhotoHash = {};
      for ( let i = 0; i < state.photos.observationPhotos.length; i++ ) {
        const observationPhoto = state.photos.observationPhotos[i];
        if ( !obsPhotoHash[observationPhoto.observation.id] ) {
          obsPhotoHash[observationPhoto.observation.id] = true;
          observationPhotos.push( observationPhoto );
        }
      }
    }
    return Object.assign( props, {
      observationPhotos,
      hasMorePhotos: ( state.photos.totalResults > state.photos.page * state.photos.perPage )
    } );
  }
  if (
    !state.taxon.taxon ||
    !state.taxon.taxon.children ||
    state.taxon.taxon.children.length === 0
  ) {
    props.showTaxonGrouping = false;
  }
  return props;
}

function mapDispatchToProps( dispatch ) {
  return {
    showTaxonPhotoModal: ( photo, taxon, observation ) => {
      dispatch( setPhotoModal( photo, taxon, observation ) );
      dispatch( showPhotoModal( ) );
    },
    loadMorePhotos: ( ) => {
      dispatch( fetchMorePhotos( ) );
    },
    setLayout: layout => {
      dispatch( setConfigAndUrl( { layout } ) );
    },
    setTerm: ( term, value ) => {
      const key = `field:${term}`;
      dispatch( updateObservationParamsAndUrl( { [key]: value === "any" ? null : value } ) );
      dispatch( reloadPhotos( ) );
    },
    setGrouping: ( param, values ) => {
      dispatch( setGrouping( param, values ) );
    },
    setParam: ( key, value ) => {
      dispatch( updateObservationParamsAndUrl( { [key]: value } ) );
      dispatch( reloadPhotos( ) );
    }
  };
}

const PhotoBrowserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoBrowser );

export default PhotoBrowserContainer;
