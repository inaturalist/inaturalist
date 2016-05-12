import React, { Component, PropTypes } from "react";
import NodeAPI from "../models/node_api";

class ProjectMap extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  reloadData( ) {
    const time = new Date( ).getTime( );
    const mapID = `map${time}${this.props.umbrella}`;
    let className;
    if ( this.props.umbrella ) { className = ".umbrella-map-slide"; }
    else { className = ".subproject-map-slide"; }
    $( `${className} .right` ).html( `<div id='${mapID}' />` );
    const map = L.map( mapID, {
      scrollWheelZoom: false,
      center: [37.166889, -95.966873],
      zoom: 4,
      zoomControl: false,
      attributionControl: false
    } );

    const inat = L.tileLayer(
      "http://tiles.inaturalist.org/v1/colored_heatmap/{z}/{x}/{y}.png?" +
      `project_id=${this.props.project.id}&color=white&ttl=600` );
    map.addLayer( inat );

    map.dragging.disable();
    map.touchZoom.disable();
    map.doubleClickZoom.disable();
    map.scrollWheelZoom.disable();
    map.keyboard.disable();

    if ( !this.props.project.place_id ) {
      $.ajax( {
        dataType: "json",
        url: "/us.geojson",
        success: data => {
          const f = { type: "Feature", geometry: data.features[0].geometry };
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
    } else {
      $.ajax( {
        dataType: "json",
        url: `http://api.inaturalist.org/v1/places/${this.props.project.place_id}?ttl=60`,
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
    }
    NodeAPI.fetch( `observations?per_page=0&project_id=${this.props.project.id}` ).
      then( json => this.props.updateState(
        { overallStats: { observations: json.total_results } } ) ).
      catch( e => console.log( e ) );
    NodeAPI.fetch( `observations/species_counts?per_page=0&project_id=${this.props.project.id}` ).
      then( json => this.props.updateState(
        { overallStats: { species: json.total_results } } ) ).
      catch( e => console.log( e ) );
    NodeAPI.fetch( `observations/identifiers?per_page=0&project_id=${this.props.project.id}` ).
      then( json => this.props.updateState(
        { overallStats: { identifiers: json.total_results } } ) ).
      catch( e => console.log( e ) );
    NodeAPI.fetch( `observations/observers?per_page=0&project_id=${this.props.project.id}` ).
      then( json => this.props.updateState(
        { overallStats: { observers: json.total_results } } ) ).
      catch( e => console.log( e ) );
  }

  render( ) {
    let className = "slide row-fluid map-slide";
    let parksStat;
    if ( this.props.umbrella ) {
      className += " umbrella";
      let parksCount;
      if ( this.props.project.id === this.props.overallID ) {
        parksCount = this.props.allSubProjects.length;
      } else if ( this.props.umbrellaSubProjects[this.props.project.id] ) {
        parksCount = this.props.umbrellaSubProjects[this.props.project.id].length;
      }
      parksStat = (
        <div className="row-fluid">
          <span className="value">
            { parksCount }
          </span>
          <span className="stat">Parks</span>
        </div>
      );
    }
    if ( this.props.umbrella ) { className += " umbrella-map-slide"; }
    else { className += " subproject-map-slide"; }
    return (
      <div className={ className }>
        <div className="left map-stats">
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
            { parksStat }
          </div>
        </div>
        <div className="right">
        </div>
      </div>
    );
  }
}

ProjectMap.propTypes = {
  project: PropTypes.object,
  overallStats: PropTypes.object,
  updateState: PropTypes.func,
  umbrellaSubProjects: PropTypes.object,
  allSubProjects: PropTypes.array,
  overallID: PropTypes.number,
  umbrella: PropTypes.bool
};

export default ProjectMap;
