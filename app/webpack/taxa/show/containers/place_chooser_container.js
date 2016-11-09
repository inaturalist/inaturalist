import { connect } from "react-redux";
import { setConfig } from "../ducks/config";
import { fetchMonthFrequency, fetchMonthOfYearFrequency } from "../ducks/observations";
import { fetchLeaders } from "../ducks/leaders";
import { fetchTaxon } from "../ducks/taxon";
import PlaceChooserPopover from "../components/place_chooser_popover";

function mapStateToProps( state ) {
  return {
    place: state.config.chosenPlace,
    defaultPlace: state.config.preferredPlace
  };
}

function mapDispatchToProps( dispatch ) {
  const setPlace = ( place ) => {
    dispatch( setConfig( { chosenPlace: place } ) );
    dispatch( fetchTaxon( ) );
    dispatch( fetchMonthFrequency( ) );
    dispatch( fetchMonthOfYearFrequency( ) );
    dispatch( fetchLeaders( ) );
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
