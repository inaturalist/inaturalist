import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import { definePopupClass } from "../util";
import colors from "../umbrella_project_colors";

class UmbrellaMap extends Component {
  componentDidMount( ) {
    const { project } = this.props;
    if ( project.hide_umbrella_map_flags ) {
      return;
    }
    setTimeout( ( ) => {
      const map = $( ".TaxonMap", ReactDOM.findDOMNode( this ) ).data( "taxonMap" );
      const Popup = definePopupClass( );
      const projectColors = _.fromPairs( _.map( project.umbrella_stats.results, ( ps, index ) => [
        ps.project.id, colors[index % colors.length]] ) );
      _.each( project.projectRules, rule => {
        const color = projectColors[rule.project.id];
        if ( rule.project.place && rule.project.place.point_geojson && typeof ( google ) !== "undefined" ) {
          const coords = rule.project.place.point_geojson.coordinates;
          const popup = new Popup(
            new google.maps.LatLng( coords[1], coords[0] ),
            color,
            (
              <a href={`/projects/${rule.project.id}`}>
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
    const {
      project,
      config
    } = this.props;
    const subprojectPlaceRules = _.compact( _.flattenDeep( _.map( project.projectRules, rule => (
      _.filter( rule.project.project_observation_rules, subRule => (
        subRule.operand_type === "Place" && subRule.operator === "observed_in_place?"
      ) )
    ) ) ) );
    const placeIDs = _.map( subprojectPlaceRules, "operand_id" );
    const totalBounds = project.recent_observations && project.recent_observations.total_bounds;
    return (
      <Grid>
        <Row>
          <Col xs={12}>
            <h2>{ I18n.t( "map_of_observations" ) }</h2>
            <TaxonMap
              placement="projects-show-umbrella"
              key={`umbrellamap${project.id}`}
              observationLayers={[{ captive: "any", ...project.search_params, color: "iconic" }]}
              showAccuracy
              enableShowAllLayer={false}
              clickable={false}
              overlayMenu={false}
              mapTypeControl
              mapTypeControlOptions={{
                style: typeof ( google ) !== "undefined" && google.maps.MapTypeControlStyle.DROPDOWN_MENU,
                position: typeof ( google ) !== "undefined" && google.maps.ControlPosition.TOP_LEFT
              }}
              zoomControlOptions={{
                position: typeof ( google ) !== "undefined" && google.maps.ControlPosition.TOP_LEFT
              }}
              placeLayers={[{ place: { id: placeIDs.join( "," ), name: "Places" } }]}
              minZoom={2}
              maxX={totalBounds && totalBounds.nelng}
              maxY={totalBounds && totalBounds.nelat}
              minX={totalBounds && totalBounds.swlng}
              minY={totalBounds && totalBounds.swlat}
              currentUser={config.currentUser}
              updateCurrentUser={config.updateCurrentUser}
            />
          </Col>
        </Row>
      </Grid>
    );
  }
}

UmbrellaMap.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object
};

UmbrellaMap.defaultProps = {
  config: {}
};

export default UmbrellaMap;
