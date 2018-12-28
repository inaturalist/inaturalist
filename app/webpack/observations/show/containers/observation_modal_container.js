import { connect } from "react-redux";
import { updateCurrentUser } from "../../../shared/ducks/config";
import ObservationModal from "../../identify/components/observation_modal";
import { addID } from "../ducks/observation";
import {
  hideCurrentObservation,
  updateCurrentObservation
} from "../../identify/actions/current_observation_actions";

function mapStateToProps( state ) {
  let images;
  const { observation } = state;
  if ( observation && observation.photos && observation.photos.length > 0 ) {
    let defaultPhotoSize = "medium";
    if ( $( ".ObservationModal .image-gallery" ).width( ) > 600 ) {
      defaultPhotoSize = "large";
    }
    images = observation.photos.map( photo => ( {
      original: photo.photoUrl( defaultPhotoSize ),
      zoom: photo.photoUrl( "original" ),
      thumbnail: photo.photoUrl( "square" ),
      originalDimensions: photo.original_dimensions
    } ) );
  }
  return Object.assign( {}, {
    images,
    currentUser: state.config.currentUser,
    tab: "suggestions",
    tabs: ["suggestions"],
    tabTitles: { suggestions: I18n.t( "compare" ) },
    hidePrevNext: true,
    hideTools: true
  }, state.currentObservation );
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideCurrentObservation( ) );
    },
    setImagesCurrentIndex: index => {
      dispatch( updateCurrentObservation( { imagesCurrentIndex: index } ) );
    },
    chooseSuggestedTaxon: ( taxon, options ) => {
      dispatch( addID( Object.assign( {}, taxon, { isVisionResult: options.vision } ) ) );
      dispatch( hideCurrentObservation( ) );
    },
    updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) )
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationModal );

export default ObservationModalContainer;
