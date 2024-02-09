import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import ReactDOMServer from "react-dom/server";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonMap from "../../../observations/identify/components/taxon_map";

/* global GEO_MODEL_TAXON */
/* global GEO_MODEL_BOUNDS */
/* global EXPECTED_NEARBY_FIGURE_URL */
/* global WEIGHTING_FIGURE_URL */
/* global RANGE_COMPARISON_FIGURE_URL */

const urlParams = new URLSearchParams( window.location.search );

const NEARBY_COLOR = urlParams.get( "nearby_color" ) || "#007DFF";
const NEARBY_OPACITY = urlParams.get( "nearby_opacity" ) || 0.4;
const RANGE_COLOR = urlParams.get( "range_color" ) || "#FF5EB0";
const RANGE_OPACITY = urlParams.get( "range_opacity" ) || 0.4;
const OVERLAP_COLOR = urlParams.get( "overlap_color" ) || "#5A57D1";
const OVERLAP_OPACITY = urlParams.get( "overlap_opacity" ) || 0.8;

const baseMapStyle = [
  {
    stylers: [
      { lightness: 50 },
      { saturation: -100 }
    ]
  }, {
    elementType: "geometry",
    stylers: [{ color: "#f5f5f5" }]
  }, {
    elementType: "labels.text.fill",
    stylers: [{ color: "#616161" }]
  }, {
    elementType: "labels.text.stroke",
    stylers: [{ color: "#f5f5f5" }]
  }, {
    featureType: "water",
    elementType: "geometry",
    stylers: [{ color: "#d9d9d9" }]
  }, {
    featureType: "water",
    elementType: "labels.text.fill",
    stylers: [{ color: "#9e9e9e" }]
  }
];

class App extends React.Component {
  constructor( ) {
    super( );
    this.map = null;
    this.setLayer = this.setLayer.bind( this );
    this.state = {
      selectedLayerIndex: null
    };
  }

  componentDidMount( ) {
    this.map = $( ".TaxonMap", ReactDOM.findDOMNode( this ) ).data( "taxonMap" );
    this.map.setOptions( {
      styles: baseMapStyle,
      minZoom: 2,
      mapTypeControl: false
    } );
    this.setState( { layer: "expectedNearbyLayer" } );
    if ( GEO_MODEL_BOUNDS && GEO_MODEL_BOUNDS.total_bounds ) {
      const {
        nelat, nelng, swlat, swlng
      } = GEO_MODEL_BOUNDS.total_bounds;
      this.map.fitBounds( new google.maps.LatLngBounds(
        new google.maps.LatLng( swlat, swlng ),
        new google.maps.LatLng( nelat, nelng )
      ) );
    }
  }

  componentDidUpdate( prevProps, prevState ) {
    const { layer } = this.state;
    if ( prevState.layer !== layer ) {
      this.setLayer( layer );
    }
  }

  setLayer( selectLayer ) {
    const { taxon } = this.props;
    if ( this.state.selectedLayerIndex ) {
      this.map.overlayMapTypes.setAt( this.state.selectedLayerIndex - 1, null );
    }
    const layerOptions = {
      taxon: {
        id: taxon.id
      },
      noOverlayControl: true,
      layerID: 1
    };
    if ( selectLayer === "expectedNearbyLayer" ) {
      this.state.selectedLayerIndex = this.map.addTaxonGeomodelLayer( {
        ...layerOptions,
        thresholded: true
      } );
    } else if ( selectLayer === "unthresholdedLayer" ) {
      this.state.selectedLayerIndex = this.map.addTaxonGeomodelLayer( layerOptions );
    } else if ( selectLayer === "expectedNearbyVsTaxonRangeLayer" ) {
      this.state.selectedLayerIndex = this.map.addTaxonGeomodelComparisonLayer( layerOptions );
    }
  }

  render( ) {
    const { taxon, config } = this.props;
    const buttons = [];
    buttons.push( (
      <button
        className={`btn btn-default${this.state.layer === "expectedNearbyLayer" ? " active" : ""}`}
        type="button"
        key="expectedNearbyLayer"
        onClick={( ) => this.setState( { layer: "expectedNearbyLayer" } )}
      >
        { I18n.t( "views.geo_model.explain.nearby_map.expected_nearby_map" ) }
      </button>
    ) );
    buttons.push( (
      <button
        className={`btn btn-default${this.state.layer === "unthresholdedLayer" ? " active" : ""}`}
        type="button"
        key="unthresholdedLayer"
        onClick={( ) => this.setState( { layer: "unthresholdedLayer" } )}
      >
        { I18n.t( "views.geo_model.explain.unthresholded_map.unthresholded_map" ) }
      </button>
    ) );
    // if the taxon has a recall value, then it was assessed against a taxon range,
    // and it will have a taxon range comparison layer to render
    if ( GEO_MODEL_TAXON.recall ) {
      buttons.push( (
        <button
          className={`btn btn-default${this.state.layer === "expectedNearbyVsTaxonRangeLayer" ? " active" : ""}`}
          type="button"
          key="expectedNearbyVsTaxonRangeLayer"
          onClick={( ) => this.setState( { layer: "expectedNearbyVsTaxonRangeLayer" } )}
        >
          { I18n.t( "views.geo_model.explain.range_comparison.expected_nearby_vs_taxon_range" ) }
        </button>
      ) );
    }

    let tabDescription;
    if ( this.state.layer === "unthresholdedLayer" ) {
      tabDescription = (
        <div>
          <p>
            { I18n.t( "views.geo_model.explain.unthresholded_map.we_use_the_unthresholded_map" ) }
          </p>
          <p
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.geo_model.explain.unthresholded_map.for_example" )
            }}
          />
          <p className="figure">
            <img
              alt={I18n.t( "views.geo_model.explain.unthresholded_map.figure_alt_text" )}
              src={WEIGHTING_FIGURE_URL}
            />
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.unthresholded_map.you_can_think" ) }
          </p>
        </div>
      );
    } else if ( this.state.layer === "expectedNearbyLayer" ) {
      tabDescription = (
        <div>
          <p>
            { I18n.t( "views.geo_model.explain.nearby_map.we_use_this_map" ) }
          </p>
          <p
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.geo_model.explain.nearby_map.for_example" )
            }}
          />
          <p className="figure">
            <img
              alt={I18n.t( "views.geo_model.explain.nearby_map.figure_alt_text" )}
              src={EXPECTED_NEARBY_FIGURE_URL}
            />
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.nearby_map.you_can_think" ) }
          </p>
        </div>
      );
    } else if ( this.state.layer === "expectedNearbyVsTaxonRangeLayer" ) {
      const precision = _.round( GEO_MODEL_TAXON.precision, 2 );
      const recall = _.round( GEO_MODEL_TAXON.recall, 2 );
      const f1 = _.round( GEO_MODEL_TAXON.f1, 2 );
      tabDescription = (
        <div>
          <p>
            { I18n.t( "views.geo_model.explain.range_comparison.this_map_shows" ) }
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.range_comparison.this_gridded_version" ) }
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.range_comparison.by_combining" ) }
          </p>
          <p className="figure comparison">
            <img
              alt={I18n.t( "views.geo_model.explain.range_comparison.figure_alt_text" )}
              src={RANGE_COMPARISON_FIGURE_URL}
            />
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.range_comparison.combining_these_maps_produces" ) }
          </p>
          <div className="row color-legend">
            <div className="col-xs-12">
              <div className="color-box" style={{ backgroundColor: NEARBY_COLOR, opacity: NEARBY_OPACITY }} />
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.false_presences_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.false_presences_definition" ) }
            </div>
          </div>
          <div className="row color-legend">
            <div className="col-xs-12">
              <div className="color-box" style={{ backgroundColor: RANGE_COLOR, opacity: RANGE_OPACITY }} />
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.false_absences_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.false_absences_definition" ) }
            </div>
          </div>
          <div className="row color-legend">
            <div className="col-xs-12">
              <div className="color-box" style={{ backgroundColor: OVERLAP_COLOR, opacity: OVERLAP_OPACITY }} />
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.true_presences_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.true_presences_definition2" ) }
            </div>
          </div>
          <div className="row">
            <div
              className="col-xs-12 evaluation-header"
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.geo_model.explain.range_comparison.evaluation_statistics_for_taxon", {
                  taxon: ReactDOMServer.renderToString(
                    <SplitTaxon
                      taxon={taxon}
                      user={config.currentUser}
                      url={`/taxa/${taxon.id}`}
                    />
                  )
                } )
              }}
            />
          </div>
          <div className="row stat-description">
            <div className="col-xs-12">
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.precision_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.precision_description" ) }
              <br />
              <span
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.geo_model.explain.range_comparison.precision_equation", {
                    precision: ReactDOMServer.renderToString( <span className="strong-label">{precision}</span> )
                  } )
                }}
              />
            </div>
          </div>
          <div className="row stat-description">
            <div className="col-xs-12">
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.recall_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.recall_description" ) }
              <br />
              <span
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.geo_model.explain.range_comparison.recall_equation", {
                    recall: ReactDOMServer.renderToString( <span className="strong-label">{recall}</span> )
                  } )
                }}
              />
            </div>
          </div>
          <div className="row stat-description">
            <div className="col-xs-12">
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.f1_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.f1_description" ) }
              <br />
              <span
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.geo_model.explain.range_comparison.f1_equation", {
                    f1: ReactDOMServer.renderToString( <span className="strong-label">{f1}</span> )
                  } )
                }}
              />
            </div>
          </div>
          <div className="row">
            <div className="col-xs-12">
              { I18n.t( "views.geo_model.explain.range_comparison.perfect_overlap" ) }
            </div>
          </div>
        </div>
      );
    }

    return (
      <div id="TaxonGeoExplain" className="container">
        <h1
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.geo_model.explain.geomodel_predictions_of_taxon", {
              taxon: ReactDOMServer.renderToString(
                <SplitTaxon
                  taxon={taxon}
                  user={config.currentUser}
                  url={`/taxa/${taxon.id}`}
                />
              )
            } )
          }}
        />
        <p>
          { I18n.t( "views.geo_model.explain.the_geo_model_makes_predictions" ) }
        </p>
        <p dangerouslySetInnerHTML={{
          __html: I18n.t( "views.geo_model.explain.the_geo_model_is_trained", { url: "/posts/84677" } )
        }}
        />
        <TaxonMap
          placement="taxa-show"
          showAllLayer={false}
          taxonLayers={[{
            taxon,
            observationLayers: [{
              label: I18n.t( "verifiable_observations" ),
              verifiable: true,
              disabled: true,
              layerID: 101
            }],
            ranges: {
              disabled: true,
              layerID: 100
            }
          }]}
          gestureHandling="auto"
          mapType={google.maps.MapTypeId.TERRAIN}
          showLegend
        />
        <div className="container">
          <div className="row">
            <div id="controls" className="btn-group">
              { buttons }
            </div>
          </div>
        </div>
        <div className="tab-description">
          { tabDescription }
        </div>
      </div>
    );
  }
}

App.propTypes = {
  taxon: PropTypes.object,
  config: PropTypes.object
};

App.defaultProps = {
  config: {}
};

export default App;
