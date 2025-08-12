import { connect } from "react-redux";
import IdentificationsTab from "../components/identifications_tab";
import {
  setIdentificationsQuery,
  voteIdentification,
  unvoteIdentification
} from "../../shared/ducks/taxon";
import { updateCurrentUser } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  const bounds = state.config.mapBounds;
  const props = {
    response: state.taxon.identifications,
    identificationsQuery: state.taxon.identificationsQuery || {},
    config: state.config,
    currentUser: state.config.currentUser,
    taxon: state.taxon.taxon
  };

  let chosenPlaceBounds;
  if ( state.config.chosenPlace && state.config.chosenPlace.bounding_box_geojson ) {
    chosenPlaceBounds = state.config.chosenPlace.bounding_box_geojson.coordinates[0];
  }
  // If the bounds is actually a point, just use that point with a moderate zoom level
  if ( chosenPlaceBounds ) {
    props.bounds = {
      swlng: chosenPlaceBounds[0][0],
      swlat: chosenPlaceBounds[0][1],
      nelng: chosenPlaceBounds[2][0],
      nelat: chosenPlaceBounds[2][1]
    };
    // Deal with bounds that cross the date line
    if ( props.bounds.swlng < 0 && props.bounds.nelng > 0 ) {
      props.bounds = {
        swlng: chosenPlaceBounds[3][0],
        swlat: chosenPlaceBounds[3][1],
        nelng: chosenPlaceBounds[1][0],
        nelat: chosenPlaceBounds[1][1]
      };
    }
  } else if (
    bounds
    && bounds.swlng
    && bounds.swlng === bounds.nelng
  ) {
    props.latitude = bounds.swlat;
    props.longitude = bounds.swlng;
    props.zoomLevel = 5;
  } else if ( bounds ) {
    props.bounds = bounds;
  } else if ( state.config.chosenPlace && state.config.chosenPlace.location ) {
    const pt = state.config.chosenPlace.location.split( "," ).map( coord => parseFloat( coord ) );
    props.latitude = pt[0];
    props.longitude = pt[1];
  } else {
    props.latitude = 0;
    props.longitude = 0;
    props.zoomLevel = 1;
  }
  return props;
}

function mapDispatchToProps( dispatch ) {
  return {
    setIdentificationsQuery: parameters => dispatch( setIdentificationsQuery( parameters ) ),
    updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) ),
    voteIdentification: ( id, vote ) => { dispatch( voteIdentification( id, vote ) ); },
    unvoteIdentification: id => { dispatch( unvoteIdentification( id ) ); }
  };
}

const IdentificationsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentificationsTab );

export default IdentificationsTabContainer;
