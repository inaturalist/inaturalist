import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import { fetchTaxon } from "../../shared/ducks/taxon";
import { fetchTaxonAssociates } from "../actions/taxon";
import PlaceChooserPopover from "../../shared/components/place_chooser_popover";
import { updateSession } from "../../../shared/util";

function mapStateToProps( state ) {
  return {
    place: state.config.chosenPlace,
    defaultPlace: state.config.preferredPlace
  };
}

function mapDispatchToProps( dispatch ) {
  const setPlace = place => {
    dispatch( setConfig( { chosenPlace: place } ) );
    updateSession( { preferred_taxon_page_place_id: place ? place.id : null } );
    dispatch( fetchTaxon( ) );
    dispatch( fetchTaxonAssociates( ) );
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
