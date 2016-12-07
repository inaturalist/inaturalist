import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import { fetchMonthFrequency, fetchMonthOfYearFrequency } from "../ducks/observations";
import { fetchLeaders } from "../ducks/leaders";
import { fetchTaxon, fetchSimilar } from "../../shared/ducks/taxon";
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
    dispatch( fetchTaxon( ) );
    dispatch( fetchMonthFrequency( ) );
    dispatch( fetchMonthOfYearFrequency( ) );
    dispatch( fetchLeaders( ) );
    dispatch( fetchSimilar( ) );
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
