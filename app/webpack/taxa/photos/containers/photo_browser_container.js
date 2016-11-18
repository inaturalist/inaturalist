import { connect } from "react-redux";
import _ from "lodash";
import PhotoBrowser from "../components/photo_browser";
import { showPhotoModal, setPhotoModal } from "../../shared/ducks/photo_modal";
import {
  fetchMorePhotos,
  updateObservationParams,
  fetchObservationPhotos
} from "../ducks/photos";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  const terms = [];
  if ( state.taxon.taxon && state.taxon.taxon.iconic_taxon_name === "Insecta" ) {
    let selectedValue;
    if ( state.photos.observationParams["field:Insect life stage"] ) {
      selectedValue = state.photos.observationParams["field:Insect life stage"];
    }
    terms.push( {
      name: "Insect life stage",
      values: [
        "adult",
        "teneral",
        "pupa",
        "nymph",
        "larva",
        "egg"
      ],
      selectedValue
    } );
  }
  if (
    state.taxon.taxon &&
    _.find( state.taxon.taxon.ancestors, a => a.name === "Magnoliophyta" )
  ) {
    let selectedValue;
    const fieldName = "Flowering Phenology";
    if ( state.photos.observationParams[`field:${fieldName}`] ) {
      selectedValue = state.photos.observationParams[`field:${fieldName}`];
    }
    terms.push( {
      name: fieldName,
      values: [
        "bare",
        "budding",
        "flower",
        "fruit"
      ],
      selectedValue
    } );
  }
  if ( state.photos.observationPhotos && state.photos.observationPhotos.length > 0 ) {
    return {
      observationPhotos: state.photos.observationPhotos,
      hasMorePhotos: ( state.photos.totalResults > state.photos.page * state.photos.perPage ),
      layout: state.config.layout,
      terms
    };
  }
  return {
    observationPhotos: [],
    hasMorePhotos: false,
    layout: state.config.layout,
    terms
  };
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
      dispatch( setConfig( { layout } ) );
    },
    setTerm: ( term, value ) => {
      const key = `field:${term}`;
      dispatch( updateObservationParams( { [key]: value === "any" ? null : value } ) );
      dispatch( fetchObservationPhotos( { reload: true } ) );
    }
  };
}

const PhotoBrowserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoBrowser );

export default PhotoBrowserContainer;
