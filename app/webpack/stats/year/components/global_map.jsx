import React from "react";
import ReactDOM from "react-dom";
import PropTypes from "prop-types";
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
      if ( site.place_id ) {
        baseOptions.place_id = site.place_id;
      } else {
        baseOptions.site_id = site.id;
      }
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
      `${apiURL}/grid/{z}/{x}/{y}.png?${$.param( thisYearOptions )}`
    ).addTo( map );
    const lastYear = L.tileLayer(
      `${apiURL}/grid/{z}/{x}/{y}.png?${$.param( lastYearOptions )}`
    ).addTo( map );
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
      year,
      return_bounds: true,
      per_page: 1
    };
    if ( site.place_id ) {
      searchParams.place_id = site.place_id;
    } else {
      searchParams.site_id = site.id;
    }
    inaturalistjs.observations.search( searchParams ).then( r => {
      // Deal with the date line for our friends in NZ
      const b = r.total_bounds;
      if ( b.swlng > 0 && b.nelng < 0 ) {
        b.nelng = 180 + 180 + b.nelng;
      }
      map.fitBounds( [
        [b.nelat, b.nelng],
        [b.swlat, b.swlng]
      ] );
    } );
  }

  render( ) {
    return (
      <div className="TorqueMap">
        <h3>
          <a name="map" href="#map">
            <span>{ I18n.t( "map" ) }</span>
          </a>
        </h3>
        <div className="map" />
      </div>
    );
  }
}

GlobalMap.propTypes = {
  site: PropTypes.object,
  year: PropTypes.number,
  interval: PropTypes.string
};

export default GlobalMap;
