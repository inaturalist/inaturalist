import React, { Component, PropTypes } from "react";
import NodeAPI from "../models/node_api";

class ProjectMap extends Component {

  componentDidMount( ) {
    const map = L.map( "map", {
      scrollWheelZoom: false,
      center: [37.166889, -95.966873],
      zoom: 4,
      zoomControl: false,
      attributionControl: false
    } );

    const inat = L.tileLayer(
      "http://tiles.inaturalist.org/v1/colored_heatmap/{z}/{x}/{y}.png?" +
      `project_id=${this.props.projectID}&color=white&ttl=60` );
    map.addLayer( inat );

    map.dragging.disable();
    map.touchZoom.disable();
    map.doubleClickZoom.disable();
    map.scrollWheelZoom.disable();
    map.keyboard.disable();

    $.ajax( {
      dataType: "json",
      url: `http://api.inaturalist.org/v1/places/${this.props.placeID}`,
      success: data => {
        const f = { type: "Feature", geometry: data.results[0].geometry_geojson };
        const myStyle = {
          color: "#ffffff",
          weight: 3,
          opacity: 0.7,
          stroke: false
        };
        const boundary = new L.geoJson( [f], myStyle );
        boundary.addTo( map );
        map.fitBounds( boundary.getBounds( ), { padding: [10, 10] } );
      }
    } );
    NodeAPI.fetch( `observations?per_page=0&project_id=${this.props.projectID}` ).
      then( json => this.props.updateState(
        { overallStats: { observations: json.total_results } } ) ).
      catch( e => console.log( e ) );
    NodeAPI.fetch( `observations/species_counts?per_page=0&project_id=${this.props.projectID}` ).
      then( json => this.props.updateState(
        { overallStats: { species: json.total_results } } ) ).
      catch( e => console.log( e ) );
    NodeAPI.fetch( `observations/identifiers?per_page=0&project_id=${this.props.projectID}` ).
      then( json => this.props.updateState(
        { overallStats: { identifiers: json.total_results } } ) ).
      catch( e => console.log( e ) );
    NodeAPI.fetch( `observations/observers?per_page=0&project_id=${this.props.projectID}` ).
      then( json => this.props.updateState(
        { overallStats: { observers: json.total_results } } ) ).
      catch( e => console.log( e ) );
  }

  render( ) {
    return (
      <div className="slide row-fluid" id="map-slide">
        <div className="col-md-5 map-stats">
          <div className="container-fluid">
            <div className="row-fluid">
              <span className="value">
                { Number( this.props.overallStats.observations ).toLocaleString( ) || "---" }
              </span>
              <span className="stat">Observations</span>
            </div>
            <div className="row-fluid">
              <span className="value">
                { Number( this.props.overallStats.species ).toLocaleString( ) || "---" }
              </span>
              <span className="stat">Species</span>
            </div>
            <div className="row-fluid">
              <span className="value">
                { Number( this.props.overallStats.identifiers ).toLocaleString( ) || "---" }
              </span>
              <span className="stat">Identifiers</span>
            </div>
            <div className="row-fluid">
              <span className="value">
                { Number( this.props.overallStats.observers ).toLocaleString( ) || "---" }
              </span>
              <span className="stat">Observers</span>
            </div>
          </div>
        </div>
        <div className="col-md-7">
          <div id="map" />
        </div>
      </div>
    );
  }
}

ProjectMap.propTypes = {
  projectID: PropTypes.number,
  placeID: PropTypes.number,
  overallStats: PropTypes.object,
  updateState: PropTypes.func
};

export default ProjectMap;
