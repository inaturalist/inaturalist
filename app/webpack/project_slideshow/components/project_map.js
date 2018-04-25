import React, { Component, PropTypes } from "react";
import Util from "../models/util";
/* global TILESERVER */

class ProjectMap extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  fitBounds( ) {
    if ( this.mapBounds ) {
      this.map.fitBounds( this.mapBounds );
    }
  }

  reloadData( ) {
    const time = new Date( ).getTime( );
    const mapID = `map${time}${this.props.umbrella}`;
    const className = this.props.umbrella ? ".umbrella-map-slide" : ".subproject-map-slide";
    $( `${className} .right` ).html( `<div id='${mapID}' />` );
    /* global L */
    this.map = L.map( mapID, {
      scrollWheelZoom: false,
      center: [39.833333, -98.5838815],
      zoom: 14,
      zoomControl: false,
      attributionControl: false
    } );

    const inat = L.tileLayer(
      `${TILESERVER}/colored_heatmap/{z}/{x}/{y}.png?` +
      `project_id=${this.props.project.id}&color=white&ttl=600` );
    this.map.addLayer( inat );

    this.map.dragging.disable();
    this.map.touchZoom.disable();
    this.map.doubleClickZoom.disable();
    this.map.scrollWheelZoom.disable();
    this.map.keyboard.disable();

    const geoJSONStyle = {
      color: "#ffffff",
      weight: 3,
      opacity: 0.7,
      stroke: false
    };

    if ( !this.props.project.place_id ) {
      $.ajax( {
        dataType: "json",
        url: "/attachments/world3.geojson",
        success: data => {
          const f = data;
          /* eslint new-cap: 0 */
          const boundary = new L.geoJson( [f], geoJSONStyle );
          boundary.addTo( this.map );
          this.fitBounds( );
        }
      } );
    } else {
      $.ajax( {
        dataType: "json",
        url: `${$( "meta[name='config:inaturalist_api_url']" ).attr( "content" )}/places/${this.props.project.place_id}?ttl=600`,
        success: data => {
          const f = { type: "Feature", geometry: data.results[0].geometry_geojson };
          const boundary = new L.geoJson( [f], geoJSONStyle );
          boundary.addTo( this.map );
          this.map.fitBounds( boundary.getBounds( ), { padding: [10, 10] } );
        }
      } );
    }
    /* eslint no-console: 0 */
    Util.nodeApiFetch( `observations?per_page=0&return_bounds=true&project_id=${this.props.project.id}` ).
      then( json => {
        this.props.updateState( { overallStats: { observations: json.total_results } } );
        if ( json.total_bounds ) {
          this.mapBounds = [
            [json.total_bounds.swlat, json.total_bounds.swlng],
            [json.total_bounds.nelat, json.total_bounds.nelng]];
          this.map.fitBounds( this.mapBounds );
        }
      } ).catch( e => console.log( e ) );
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
          <div className="stat">{ I18n.t( "of_places" ) }</div>
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
              <div className="stat">{ I18n.t( "of_observations" ) }</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                { Util.numberWithCommas( this.props.overallStats.species ) }
              </div>
              <div className="stat">{ I18n.t( "of_species" ) }</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                { Util.numberWithCommas( this.props.overallStats.identifiers ) }
              </div>
              <div className="stat">{ I18n.t( "of_identifiers" ) }</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                { Util.numberWithCommas( this.props.overallStats.observers ) }
              </div>
              <div className="stat">{ I18n.t( "of_observers" ) }</div>
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
