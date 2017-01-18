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
    params: state.photos.observationParams,
    place: state.config.chosenPlace
  };
  props.terms = Object.assign( { }, state.taxon.fieldValues || { } );
  // group terms by attribute for easier rendering of term filters
  if ( props.params.term_id && props.params.term_value_id ) {
    const match = props.terms[props.params.term_id];
    if ( match && match.length > 0 ) {
      const valueMatch = _.find( match, m => (
        m.controlled_value.id === Number( props.params.term_value_id )
      ) );
      if ( valueMatch && match ) {
        props.selectedTerm = match[0].controlled_attribute;
        props.selectedTermValue = valueMatch.controlled_value;
      }
    }
  }
  if ( state.photos.observationPhotos && state.photos.observationPhotos.length > 0 ) {
    return Object.assign( props, {
      observationPhotos: state.photos.observationPhotos,
      hasMorePhotos: ( state.photos.totalResults > state.photos.page * state.photos.perPage )
    } );
  } else if ( state.photos.observationPhotos ) {
    props.observationPhotos = [];
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
      const clear = ( value === "any" );
      dispatch( setConfigAndUrl( { grouping: { } } ) );
      dispatch( updateObservationParamsAndUrl( {
        term_id: clear ? null : term,
        term_value_id: clear ? null : value
      } ) );
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
