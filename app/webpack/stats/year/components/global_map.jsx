import React from "react";
import ReactDOM from "react-dom";
import moment from "moment-timezone";
import inaturalistjs from "inaturalistjs";
/* global L */
/* global DEFAULT_SITE_ID */

class GlobalMap extends React.Component {

  componentDidMount( ) {
    const map = this.setupMap( );
    this.centerMapOnResultBounds( map );
  }

  setupMap( ) {
    const { site, year } = this.props;
    const map = new L.Map( $( ".map", ReactDOM.findDOMNode( this ) )[0], {
      zoomControl: true,
      center: [
        20,
        10
      ],
      zoom: 2,
      keyboard: false,
      scrollWheelZoom: false
    } );
    const apiURL = $( "meta[name='config:inaturalist_api_url']" ).attr( "content" );
    L.tileLayer( "https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_nolabels/{z}/{x}/{y}.png", {
      attribution: "CartoDB"
    } ).addTo( map );
    const baseOptions = {
      line_width: 1,
      line_opacity: 0.3,
      scaled: true,
      width: 8,
      comp_op: "src-over",
      ttl: 86400
    };
    if ( site && site.id !== DEFAULT_SITE_ID ) {
      baseOptions.site_id = site.id;
    }
    const thisYearOptions = Object.assign( { }, baseOptions, {
      year,
      line_color: "#ff6300",
      color: "#ff6300"
    } );
    const lastYearOptions = Object.assign( { }, baseOptions, {
      year: year - 1,
      line_color: "#ffee91",
      color: "#ffee91"
    } );
    const thisYear = L.tileLayer(
      `${apiURL}/colored_heatmap/{z}/{x}/{y}.png?${$.param( thisYearOptions )}` ).addTo( map );
    const lastYear = L.tileLayer(
      `${apiURL}/colored_heatmap/{z}/{x}/{y}.png?${$.param( lastYearOptions )}` ).addTo( map );
    L.control.layers( { },
      {
        [I18n.t( "x_observations", { count: year - 1 } )]: lastYear,
        [I18n.t( "x_observations", { count: year } )]: thisYear
      }, { collapsed: false } ).addTo( map );
    setTimeout( ( ) => {
      const toggle = $( "<div/>" ).addClass( "leaflet-bar leaflet-control layer-toggle" );
      toggle.append( $( "<a>" ).addClass( "leaflet-control-layers-toggle" ) );
      $( ".leaflet-top.leaflet-right" ).prepend( toggle );
      toggle.on( "click", e => {
        e.stopPropagation( );
        $( ".leaflet-control-layers" ).toggle( );
      } );
      $( ".leaflet-control-layers-overlays input:first" ).click( );
    }, 10 );
    lastYear.bringToFront( );
    return map;
  }

  centerMapOnResultBounds( map ) {
    const { site, year } = this.props;
    if ( !site || site.id === DEFAULT_SITE_ID ) { return; }
    const searchParams = {
      site_id: site.id,
      year,
      return_bounds: true,
      per_page: 1
    };
    inaturalistjs.observations.search( searchParams ).then( r => {
      map.fitBounds( [
        [r.total_bounds.nelat, r.total_bounds.nelng],
        [r.total_bounds.swlat, r.total_bounds.swlng]
      ] );
    } );
  }

  render( ) {
    return (
      <div className="TorqueMap">
        <h3><span>{ I18n.t( "map" ) }</span></h3>
        <div className="map" />
      </div>
    );
  }
}

GlobalMap.propTypes = {
  site: React.PropTypes.object,
  year: React.PropTypes.number,
  interval: React.PropTypes.string
};

export default GlobalMap;
