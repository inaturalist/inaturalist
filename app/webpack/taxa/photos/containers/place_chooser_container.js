import { connect } from "react-redux";
import { reloadPhotos, setConfigAndUrl } from "../ducks/photos";
import PlaceChooserPopover from "../../shared/components/place_chooser_popover";
import { updateSession } from "../../../shared/util";
import { fetchTerms } from "../../shared/ducks/taxon";

function mapStateToProps( state ) {
  return {
    place: state.config.chosenPlace,
    defaultPlace: state.config.preferredPlace
  };
}

function mapDispatchToProps( dispatch ) {
  const setPlace = ( place ) => {
    dispatch( setConfigAndUrl( { chosenPlace: place } ) );
    // reload terms to filter by chosen place
    dispatch( fetchTerms( ) );
    updateSession( { preferred_taxon_page_place_id: place ? place.id : null } );
    dispatch( reloadPhotos( ) );
  };
  return {
    setPlace,
    clearPlace: ( ) => setPlace( null )
  };
}

const PlaceChooserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PlaceChooserPopover );

export default PlaceChooserContainer;
