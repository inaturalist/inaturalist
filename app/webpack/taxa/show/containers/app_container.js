import { connect } from "react-redux";
import App from "../components/app";
import { setConfig } from "../ducks/config";
import { fetchMonthFrequency, fetchMonthOfYearFrequency } from "../ducks/observations";
import { fetchLeaders } from "../ducks/leaders";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    place: state.config.preferredPlace
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setPlace: ( place ) => {
      dispatch( setConfig( { preferredPlace: place } ) );
      dispatch( fetchMonthFrequency( ) );
      dispatch( fetchMonthOfYearFrequency( ) );
      dispatch( fetchLeaders( ) );
    }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;

