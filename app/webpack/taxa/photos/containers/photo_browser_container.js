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
  const terms = [];
  const props = {
    hasMorePhotos: false,
    layout: state.config.layout,
    grouping: state.config.grouping,
    groupedPhotos: state.photos.groupedPhotos,
    terms,
    params: state.photos.observationParams
  };
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
    return Object.assign( props, {
      observationPhotos: state.photos.observationPhotos,
      hasMorePhotos: ( state.photos.totalResults > state.photos.page * state.photos.perPage )
    } );
  }
  // if ( !state.photos.observationPhotos ) {
  //   props.hasMorePhotos = true;
  // }
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
