import React, { Component, PropTypes } from "react";
import Util from "../models/util";

class ProjectMap extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  reloadData( ) {
    const time = new Date( ).getTime( );
    const mapID = `map${time}${this.props.umbrella}`;
    const className = this.props.umbrella ? ".umbrella-map-slide" : ".subproject-map-slide";
    $( `${className} .right` ).html( `<div id='${mapID}' />` );
    /* global L */
    const map = L.map( mapID, {
      scrollWheelZoom: false,
      center: [39.833333, -98.5838815],
      zoom: 14,
      zoomControl: false,
      attributionControl: false
    } );

    const inat = L.tileLayer(
      // "https://tiles.inaturalist.org/v1/colored_heatmap/{z}/{x}/{y}.png?" +
      "https://tiles.inaturalist.org/v1/colored_heatmap/{z}/{x}/{y}.png?" +
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
        url: "/attachments/us.geojson",
        success: data => {
          const f = { type: "Feature", geometry: data.features[0].geometry };
          const myStyle = {
            color: "#ffffff",
            weight: 3,
            opacity: 0.7,
            stroke: false
          };
          /* eslint new-cap: 0 */
          const boundary = new L.geoJson( [f], myStyle );
          boundary.addTo( map );
          map.fitBounds( boundary.getBounds( ), { padding: [10, 10] } );
        }
      } );
    } else {
      $.ajax( {
        dataType: "json",
        url: `${$( "meta[name='config:inaturalist_api_url']" ).attr( "content" )}/places/${this.props.project.place_id}?ttl=60`,
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
    /* eslint no-console: 0 */
    Util.nodeApiFetch( `observations?per_page=0&project_id=${this.props.project.id}` ).
      then( json => this.props.updateState(
        { overallStats: { observations: json.total_results } } ) ).
      catch( e => console.log( e ) );
    Util.nodeApiFetch( `observations/species_counts?per_page=0&project_id=${this.props.project.id}` ).
      then( json => this.props.updateState(
        { overallStats: { species: json.total_results } } ) ).
      catch( e => console.log( e ) );
    Util.nodeApiFetch( `observations/identifiers?per_page=0&project_id=${this.props.project.id}` ).
      then( json => this.props.updateState(
        { overallStats: { identifiers: json.total_results } } ) ).
      catch( e => console.log( e ) );
    Util.nodeApiFetch( `observations/observers?per_page=0&project_id=${this.props.project.id}` ).
      then( json => this.props.updateState(
        { overallStats: { observers: json.total_results } } ) ).
      catch( e => console.log( e ) );
  }

  render( ) {
    let className = "slide row-fluid map-slide";
    let parksStat;
    if ( this.props.umbrella && !this.props.singleProject ) {
      className += " umbrella";
      let parksCount;
      if ( this.props.project.id === this.props.overallID ) {
        parksCount = this.props.allSubProjects.length;
      } else if ( this.props.umbrellaSubProjects[this.props.project.id] ) {
        parksCount = this.props.umbrellaSubProjects[this.props.project.id].length;
      }
      parksStat = (
        <div className="row-fluid">
          <div className="value">
            { parksCount }
          </div>
          <div className="stat">Parks</div>
        </div>
      );
    }
    className += this.props.umbrella ? " umbrella-map-slide" : " subproject-map-slide";
    return (
      <div className={ className }>
        <div className="left map-stats">
          <div className="container-fluid">
            <div className="row-fluid">
              <div className="value">
                { Util.numberWithCommas( this.props.overallStats.observations ) }
              </div>
              <div className="stat">Observations</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                { Util.numberWithCommas( this.props.overallStats.species ) }
              </div>
              <div className="stat">Species</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                { Util.numberWithCommas( this.props.overallStats.identifiers ) }
              </div>
              <div className="stat">Identifiers</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                { Util.numberWithCommas( this.props.overallStats.observers ) }
              </div>
              <div className="stat">Observers</div>
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
  singleProject: PropTypes.object,
  overallStats: PropTypes.object,
  updateState: PropTypes.func,
  umbrellaSubProjects: PropTypes.object,
  allSubProjects: PropTypes.array,
  overallID: PropTypes.number,
  umbrella: PropTypes.bool
};

export default ProjectMap;
