import React from "react";
import $ from "jquery";
import _ from "lodash";
import { render } from "@testing-library/react";
import Charts from "./charts";

global.$ = $;
global.jQuery = $;

// jsdom doesn't implement SVG layout, which billboard.js relies on for text/tick sizing.
window.SVGElement.prototype.getBBox = ( ) => ( {
  x: 0, y: 0, width: 0, height: 0, toJSON( ) { return this; }
} );
window.SVGElement.prototype.getComputedTextLength = ( ) => 0;
// jsdom's getBoundingClientRect doesn't implement DOMRect's toJSON either.
window.Element.prototype.getBoundingClientRect = ( ) => ( {
  x: 0, y: 0, top: 0, left: 0, right: 0, bottom: 0, width: 0, height: 0, toJSON( ) { return this; }
} );
// jsdom doesn't implement SVGAnimatedLength, which d3-zoom's defaultExtent() needs
// to compute a zoomable SVG's extent.
Object.defineProperty( window.SVGSVGElement.prototype, "width", {
  configurable: true,
  get( ) { return { baseVal: { value: 0 } }; }
} );
Object.defineProperty( window.SVGSVGElement.prototype, "height", {
  configurable: true,
  get( ) { return { baseVal: { value: 0 } }; }
} );

const seasonalityKeys = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
const seasonalityColumns = [
  ["verifiable", 3, 5, 8, 12, 20, 25, 22, 18, 14, 9, 6, 4],
  ["research", 1, 2, 3, 5, 9, 12, 10, 8, 6, 4, 2, 1],
  ["Flowers and Fruits=Flowers", 0, 0, 1, 4, 8, 10, 9, 5, 2, 1, 0, 0],
  ["Flowers and Fruits=No Flowers or Fruits", 3, 5, 7, 8, 12, 15, 13, 13, 12, 8, 6, 4]
];

// >= 10 distinct years to exercise the "decade zoom" branch in renderHistoryChart
const historyYears = _.range( 2012, 2023 );
const historyKeys = historyYears.map( y => `${y}-01-01` );
const historyColumns = [
  ["x", ...historyKeys],
  ["verifiable", ...historyYears.map( ( y, i ) => 10 + i )],
  ["research", ...historyYears.map( ( y, i ) => 5 + i )]
];

const chartedFieldValues = {
  123: [
    {
      controlled_attribute: { id: 1, label: "Flowers and Fruits" },
      controlled_value: { id: 11, label: "Flowers" },
      month_of_year: {}
    },
    {
      controlled_attribute: { id: 1, label: "Flowers and Fruits" },
      controlled_value: { id: 12, label: "No Flowers or Fruits" },
      month_of_year: {}
    }
  ]
};

const defaultProps = {
  seasonalityKeys,
  seasonalityColumns,
  historyKeys,
  historyColumns,
  chartedFieldValues,
  colors: {},
  taxon: { id: 1 },
  config: {},
  openObservationsSearch: () => {},
  setNoAnnotationHiddenPreference: () => {},
  setScaledPreference: () => {},
  loadFieldValueChartData: () => {},
  fetchMonthFrequency: () => {}
};

describe( "Charts", ( ) => {
  it( "renders the seasonality, history, and field-value charts without throwing", ( ) => {
    const { container, rerender } = render( <Charts {...defaultProps} /> );

    const seasonalityChart = container.querySelector( "#SeasonalityChart" );
    expect( seasonalityChart ).not.toBeNull( );
    expect( seasonalityChart.querySelector( "svg" ) ).not.toBeNull( );

    // Only componentDidMount runs on initial render (renders the seasonality chart
    // only); componentDidUpdate is what renders the history and field-value charts.
    rerender( <Charts {...defaultProps} scaled /> );

    const historyChart = container.querySelector( "#HistoryChart" );
    expect( historyChart ).not.toBeNull( );
    expect( historyChart.querySelector( "svg" ) ).not.toBeNull( );

    const fieldValueChart = container.querySelector( "#FieldValueChart123" );
    expect( fieldValueChart ).not.toBeNull( );
    expect( fieldValueChart.querySelector( "svg" ) ).not.toBeNull( );
  } );

  it( "renders the seasonality tooltip on hover without throwing or stripping content", ( ) => {
    const instance = React.createRef( );
    render( <Charts ref={instance} {...defaultProps} /> );

    expect( ( ) => {
      instance.current.seasonalityChart.tooltip.show( { data: { x: 4 } } );
    } ).not.toThrow( );

    const tooltip = document.querySelector( ".frequency-chart-tooltip" );
    expect( tooltip ).not.toBeNull( );
    expect( tooltip.querySelector( ".swatch" ) ).not.toBeNull( );
    expect( tooltip.querySelector( ".swatch" ).getAttribute( "style" ) ).toMatch( /background-color/ );
  } );

  it( "handles empty seasonality/history data without throwing", ( ) => {
    const { container } = render( (
      <Charts
        {...defaultProps}
        seasonalityKeys={[]}
        seasonalityColumns={[]}
        historyKeys={[]}
        historyColumns={[]}
        chartedFieldValues={undefined}
      />
    ) );
    expect( container.querySelector( "#charts" ) ).not.toBeNull( );
  } );
} );
