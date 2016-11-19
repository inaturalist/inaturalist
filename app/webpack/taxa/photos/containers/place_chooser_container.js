import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import { reloadPhotos } from "../ducks/photos";
import PlaceChooserPopover from "../../shared/components/place_chooser_popover";

function mapStateToProps( state ) {
  return {
    place: state.config.chosenPlace,
    defaultPlace: state.config.preferredPlace
  };
}

function mapDispatchToProps( dispatch ) {
  const setPlace = ( place ) => {
    dispatch( setConfig( { chosenPlace: place } ) );
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
