import React, { Component, PropTypes } from "react";
import Util from "../../project_slideshow/models/util";

class ResultsMap extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  reloadData( ) {
    const time = new Date( ).getTime( );
    const mapID = `map${time}`;
    $( ".map-slide .right" ).html( `<div id='${mapID}' />` );
    /* global L */
    this.map = L.map( mapID, {
      scrollWheelZoom: false,
      zoomControl: false,
      attributionControl: false
    } );

    const tileParams = {
      color: "#74ac00",
      width: 6,
      opacity: 1,
      line_width: 0.4,
      line_opacity: 1,
      comp_op: "src",
      ttl: 600
    };

    /* global TILESERVER */
    const inat = L.tileLayer(
      `${TILESERVER}/colored_heatmap/{z}/{x}/{y}.png?` +
      `${$.param( this.props.searchParams )}&${$.param( tileParams )}`, { noWrap: true } );
    this.map.addLayer( inat );

    this.map.dragging.disable();
    this.map.touchZoom.disable();
    this.map.doubleClickZoom.disable();
    this.map.scrollWheelZoom.disable();
    this.map.keyboard.disable();

    const geoJSONStyle = {
      color: "#000",
      weight: 3,
      fillOpacity: 0.08,
      stroke: false
    };
    if ( this.props.searchParams.place_id ) {
      $.ajax( {
        dataType: "json",
        url: `${$( "meta[name='config:inaturalist_api_url']" ).attr( "content" )}/places/${this.props.searchParams.place_id}?ttl=600`,
        success: data => {
          const f = { type: "Feature", geometry: data.results[0].geometry_geojson };
          const boundary = new L.geoJson( [f], geoJSONStyle );
          boundary.addTo( this.map );
          this.map.fitBounds( boundary.getBounds( ), { padding: [10, 10] } );
        }
      } );
    } else {
      $.ajax( {
        dataType: "json",
        url: "/attachments/world3.geojson",
        success: data => {
          const f = data;
          /* eslint new-cap: 0 */
          const boundary = new L.geoJson( [f], geoJSONStyle );
          boundary.addTo( this.map );
        }
      } );
    }

    /* eslint no-console: 0 */
    const params = $.param( this.props.searchParams );
    Util.nodeApiFetch( `observations?per_page=0&return_bounds=true&${params}` ).
      then( json => {
        this.props.updateState( { overallStats: { observations: json.total_results } } );
        this.props.updateState( { overallStats: { bounds: json.total_bounds } } );
      } ).catch( e => console.log( e ) );
    Util.nodeApiFetch( `observations/species_counts?per_page=0&${params}` ).
      then( json => this.props.updateState(
        { overallStats: { species: json.total_results } } ) ).
      catch( e => console.log( e ) );
    Util.nodeApiFetch( `observations/identifiers?per_page=0&${params}` ).
      then( json => this.props.updateState(
        { overallStats: { identifiers: json.total_results } } ) ).
      catch( e => console.log( e ) );
    Util.nodeApiFetch( `observations/observers?per_page=0&${params}` ).
      then( json => this.props.updateState(
        { overallStats: { observers: json.total_results } } ) ).
      catch( e => console.log( e ) );
  }

  render( ) {
    let className = "slide row-fluid map-slide";
    if ( this.map && this.props.overallStats.bounds ) {
      const bounds = this.props.overallStats.bounds;
      this.map.fitBounds( [
        [bounds.swlat, bounds.swlng],
        [bounds.nelat, bounds.nelng]] );
    }
    return (
      <div className={ className }>
        <div className="left map-stats">
          <div className="container-fluid">
            <div className="row-fluid">
              <div className="value">
                <a href={ `/observations?${$.param( this.props.searchParams )}`}>
                  { Util.numberWithCommas( this.props.overallStats.observations ) }
                </a>
              </div>
              <div className="stat">Observations</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                <a href={ `/observations?view=species&${$.param( this.props.searchParams )}`}>
                  { Util.numberWithCommas( this.props.overallStats.species ) }
                </a>
              </div>
              <div className="stat">Species</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                <a href={ `/observations?view=identifiers&${$.param( this.props.searchParams )}`}>
                  { Util.numberWithCommas( this.props.overallStats.identifiers ) }
                </a>
              </div>
              <div className="stat">Identifiers</div>
            </div>
            <div className="row-fluid">
              <div className="value">
                <a href={ `/observations?view=observers&${$.param( this.props.searchParams )}`}>
                  { Util.numberWithCommas( this.props.overallStats.observers ) }
                </a>
              </div>
              <div className="stat">Observers</div>
            </div>
          </div>
        </div>
        <div className="right">
        </div>
      </div>
    );
  }
}

ResultsMap.propTypes = {
  searchParams: PropTypes.object,
  overallStats: PropTypes.object,
  updateState: PropTypes.func
};

export default ResultsMap;
