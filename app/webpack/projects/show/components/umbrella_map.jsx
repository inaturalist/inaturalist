import _ from "lodash";
import React, { PropTypes, Component } from "react";
import ReactDOM from "react-dom";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import { definePopupClass } from "../util";

class UmbrellaMap extends Component {


  componentDidMount( ) {
    setTimeout( ( ) => {
      const map = $( ".TaxonMap", ReactDOM.findDOMNode( this ) ).data( "taxonMap" );
      const Popup = definePopupClass( );
      const colors = ["#127faa", "#75aa1f", "#1aaba3", "#aa17a3", "#f3474a", "#ce5abe", "#425cca"];
      _.each( this.props.project.projectRules, ( rule, index ) => {
        const color = colors[index % colors.length];
        if ( rule.project.place && rule.project.place.point_geojson ) {
          const coords = rule.project.place.point_geojson.coordinates;
          const popup = new Popup(
            new google.maps.LatLng( coords[1], coords[0] ),
            color,
            (
              <a href={ `/projects/${rule.project.id}` }>
                <div className="iwclass">{ rule.project.title }</div>
              </a>
            )
          );
          popup.setMap( map );
        }
      } );
    }, 1000 );
  }

  render( ) {
    const { project } = this.props;
    const subprojectPlaceRules = _.compact( _.flattenDeep( _.map( project.projectRules, rule => (
      _.filter( rule.project.project_observation_rules, subRule => (
        subRule.operand_type === "Place"
      ) )
    ) ) ) );
    const placeIDs = _.map( subprojectPlaceRules, "operand_id" );
    const totalBounds = project.recent_observations && project.recent_observations.total_bounds;
    return (
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <h2>{ I18n.t( "map_of_observations" ) }</h2>
            <TaxonMap
              key={ `umbrellamap${project.id}` }
              observationLayers={ [project.search_params] }
              showAccuracy
              enableShowAllLayer={ false }
              clickable={ false }
              scrollwheel={ false }
              overlayMenu={ false }
              mapTypeControl
              mapTypeControlOptions={{
                style: google.maps.MapTypeControlStyle.DROPDOWN_MENU,
                position: google.maps.ControlPosition.TOP_LEFT
              }}
              zoomControlOptions={{ position: google.maps.ControlPosition.TOP_LEFT }}
              placeLayers={ [{ place: { id: placeIDs.join( "," ), name: "Places" } }] }
              minZoom={ 2 }
              maxX={ totalBounds && totalBounds.nelng }
              maxY={ totalBounds && totalBounds.nelat }
              minX={ totalBounds && totalBounds.swlng }
              minY={ totalBounds && totalBounds.swlat }
            />
          </Col>
        </Row>
      </Grid>
    );
  }
}

UmbrellaMap.propTypes = {
  setConfig: PropTypes.func,
  project: PropTypes.object,
  config: PropTypes.object
};

export default UmbrellaMap;
