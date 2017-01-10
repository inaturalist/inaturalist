import { connect } from "react-redux";
import TaxonPageMap from "../components/taxon_page_map";

function mapStateToProps( state ) {
  const bounds = state.config.mapBounds;
  const props = { taxon: state.taxon.taxon };
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
  } else if (
    bounds &&
    bounds.swlng &&
    bounds.swlng === bounds.nelng
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

function mapDispatchToProps( ) {
  return { };
}

const TaxonPageMapContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonPageMap );

export default TaxonPageMapContainer;
