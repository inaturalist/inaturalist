import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import c3 from "c3";
import moment from "moment";
import { objectToComparable } from "../../../shared/util";

class Charts extends React.Component {
  componentDidMount( ) {
    this.renderSeasonalityChart( );
    this.resetChartTabEvents( );
  }
  shouldComponentUpdate( nextProps ) {
    if (
      _.isEqual(
        objectToComparable( this.props.seasonalityColumns ),
        objectToComparable( nextProps.seasonalityColumns )
      )
      &&
      _.isEqual(
        objectToComparable( this.props.historyColumns ),
        objectToComparable( nextProps.historyColumns )
      )
    ) {
      // No change in underlying data series, don't update
      return false;
    }
    return true;
  }
  componentDidUpdate( ) {
    this.renderSeasonalityChart( );
    this.renderHistoryChart( );
    this.renderFieldValueCharts( );
    this.resetChartTabEvents( );
  }
  resetChartTabEvents( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "a[data-toggle=tab]", domNode ).unbind( "shown.bs.tab" );
    $( "a[data-toggle=tab]", domNode ).bind( "shown.bs.tab", e => {
      if ( e.target.hash === "#charts-seasonality" ) {
        if ( this.seasonalityChart ) {
          this.seasonalityChart.flush( );
        }
      } else if ( e.target.hash === "#charts-history" ) {
        if ( this.historyChart ) {
          this.historyChart.flush( );
        }
      } else {
        const match = e.target.hash.match( /field-values-([0-9]+)$/ );
        if ( match && this.fieldValueCharts[Number( match[1] )] ) {
          this.fieldValueCharts[Number( match[1] )].flush( );
        }
      }
    } );
  }
  defaultC3Config( ) {
    return {
      data: {
        colors: this.props.colors,
        types: {
          verifiable: "spline",
          research: "area-spline"
        },
        // For some reason this is necessary to enable the cursor style on the points
        selection: {
          enabled: true
        }
      },
      axis: {
        y: {
          min: 0,
          show: true,
          padding: {
            left: 0,
            bottom: 0
          },
          tick: {
            outer: false,
            format: d => I18n.toNumber( d, { precision: 0 } )
          }
        }
      },
      legend: {
        show: false
      },
      point: {
        r: 3,
        focus: {
          expand: {
            r: 4
          }
        }
      }
    };
  }
  tooltipContent( data, defaultTitleFormat, defaultValueFormat, color, tipTitle ) {
    const order = _.map( this.props.seasonalityColumns, c => ( c[0] ) );
    const tipRows = order.map( seriesName => {
      const item = _.find( data, series => series.name === seriesName );
      if ( item ) {
        return `
          <div class="series">
            <span class="swatch" style="background-color: ${color( item )}"></span>
            <span class="column-label">${I18n.t( `views.taxa.show.frequency.${item.name}`,
              { defaultValue: item.name.split( "=" )[1] } )}:</span>
            <span class="value">${I18n.toNumber( item.value, { precision: 0 } )}</span>
          </div>
        `;
      }
      return null;
    } );
    return `
      <div class="frequency-chart-tooltip">
        <div class="title">${tipTitle}</div>
        ${tipRows.join( "" )}
      </div>
    `;
  }
  seasonalityConfigForColumns( columns, options = { } ) {
    const that = this;
    const pointSearchOptions = { };
    if ( options.controlled_attribute ) {
      pointSearchOptions.term_id = options.controlled_attribute.id;
    }
    return _.defaultsDeep( { }, this.defaultC3Config( ), {
      data: {
        columns,
        onclick: d => {
          const searchOptions = Object.assign( { }, pointSearchOptions, { month: d.x + 1 } );
          if ( options.labels_to_value_ids && options.labels_to_value_ids[d.id] ) {
            searchOptions.term_value_id = options.labels_to_value_ids[d.id];
          }
          that.seasonalityChart.unselect( ["verifiable", "research"] );
          that.props.openObservationsSearch( searchOptions );
        }
      },
      axis: {
        x: {
          type: "category",
          categories: this.props.seasonalityKeys.map( i =>
            I18n.t( "date.abbr_month_names" )[i].toUpperCase( ) ),
          tick: {
            multiline: false
          }
        }
      },
      tooltip: {
        contents: ( d, defaultTitleFormat, defaultValueFormat, color ) => that.tooltipContent(
          d, defaultTitleFormat, defaultValueFormat, color,
          `${I18n.t( "observations_total" )}: ${I18n.t( "date.month_names" )[d[0].index + 1]}`
        )
      }
    } );
  }
  renderSeasonalityChart( ) {
    const config = this.seasonalityConfigForColumns(
      _.filter( this.props.seasonalityColumns, column =>
        column[0] === "verifiable" || column[0] === "research" )
    );
    const mountNode = $( "#SeasonalityChart", ReactDOM.findDOMNode( this ) ).get( 0 );
    this.seasonalityChart = c3.generate( Object.assign( { bindto: mountNode }, config ) );
  }
  renderFieldValueCharts( ) {
    this.fieldValueCharts = this.fieldValueCharts || { };
    if ( !this.props.chartedFieldValues ) { return; }
    _.each( this.props.chartedFieldValues, ( values, termID ) => {
      const columns = _.filter( this.props.seasonalityColumns, column =>
        _.startsWith( column[0], `${values[0].controlled_attribute.label}=` ) );
      const labelsToValueIDs = _.fromPairs( _.map( values, v => (
        [`${v.controlled_attribute.label}=${v.controlled_value.label}`,
          v.controlled_value.id] ) ) );
      const config = this.seasonalityConfigForColumns( columns, {
        controlled_attribute: values[0].controlled_attribute,
        labels_to_value_ids: labelsToValueIDs } );
      config.data.types = { };
      for ( let i = 0; i < columns.length; i++ ) {
        config.data.types[columns[i][0]] = "area-spline";
      }
      config.data.order = null;
      const mountNode = $( `#FieldValueChart${termID}`, ReactDOM.findDOMNode( this ) ).get( 0 );
      this.fieldValueCharts[termID] = c3.generate(
        Object.assign( { bindto: mountNode }, config ) );
    } );
  }
  renderHistoryChart( ) {
    const dates = this.props.historyKeys;
    const years = _.uniq( dates.map( d => new Date( d ).getFullYear( ) ) ).sort( );
    const chunks = _.chunk( years, 2 );
    const that = this;
    const regions = chunks.map( pair => (
      {
        start: `${pair[0]}-01-01`,
        end: `${pair[0] + 1}-01-01`
      }
    ) );
    const config = _.defaultsDeep( { }, this.defaultC3Config( ), {
      data: {
        x: "x",
        columns: this.props.historyColumns,
        onclick: d => {
          this.props.openObservationsSearch( {
            quality_grade: ( d.name === "research" ? "research" : null ),
            year: d.x.getFullYear( ),
            month: d.x.getMonth( ) + 1
          } );
        }
      },
      axis: {
        x: {
          type: "timeseries",
          tick: {
            culling: true,
            values: years.map( y => `${y}-06-15` ),
            format: "%Y"
          },
          extent: [moment( ).subtract( 10, "years" ).toDate( ), new Date( )]
        }
      },
      zoom: {
        enabled: true,
        rescale: true
      },
      tooltip: {
        contents: ( d, defaultTitleFormat, defaultValueFormat, color ) => that.tooltipContent(
          d, defaultTitleFormat, defaultValueFormat, color,
          `${I18n.t( "observations_total" )}:
          ${I18n.t( "date.abbr_month_names" )[d[0].x.getMonth( ) + 1]}
          ${d[0].x.getFullYear( )}`
        )
      },
      regions
    } );
    const mountNode = $( ".HistoryChart", ReactDOM.findDOMNode( this ) ).get( 0 );
    this.historyChart = c3.generate( Object.assign( { bindto: mountNode }, config ) );
  }
  render( ) {
    const noHistoryData = _.isEmpty( this.props.historyKeys );
    const noSeasonalityData = _.isEmpty( this.props.seasonalityKeys );
    let fieldValueTabs = [];
    let fieldValuePanels = [];
    if ( this.props.chartedFieldValues ) {
      _.each( this.props.chartedFieldValues, ( values, termID ) => {
        fieldValueTabs.push( (
          <li role="presentation" key={ `charts-field-values-${termID}` }>
            <a
              href={ `#charts-field-values-${termID}` }
              aria-controls={ `charts-field-values-${termID}` }
              role="tab"
              data-toggle="tab"
            >
              { values[0].controlled_attribute.label }
            </a>
          </li>
        ) );
        fieldValuePanels.push( (
          <div role="tabpanel" className="tab-pane" id={ `charts-field-values-${termID}` }
            key={ `charts-field-values-${termID}` }
          >
            <div
              className={
                `no-content text-muted text-center ${noSeasonalityData ? "" : "hidden"}`
              }
            >
              { I18n.t( "no_observations_yet" ) }
            </div>
            <div id={ `FieldValueChart${termID}` } className="SeasonalityChart FrequencyChart">
            </div>
          </div>
        ) );
      } );
    }
    return (
      <div id="charts" className="Charts">
        <ul className="nav nav-tabs" role="tablist">
          <li role="presentation" className="active">
            <a
              href="#charts-seasonality"
              aria-controls="charts-seasonality"
              role="tab"
              data-toggle="tab"
            >
              { I18n.t( "seasonality" ) }
            </a>
          </li>
          <li role="presentation">
            <a
              href="#charts-history"
              aria-controls="charts-history"
              role="tab"
              data-toggle="tab"
            >
              { I18n.t( "history" ) }
            </a>
          </li>
          { fieldValueTabs }
        </ul>
        <div className="tab-content">
          <div role="tabpanel" className="tab-pane active" id="charts-seasonality">
            <div
              className={
                `no-content text-muted text-center ${noSeasonalityData ? "" : "hidden"}`
              }
            >
              { I18n.t( "no_observations_yet" ) }
            </div>
            <div id="SeasonalityChart" className="SeasonalityChart FrequencyChart">
            </div>
          </div>
          <div role="tabpanel" className="tab-pane" id="charts-history">
            <div
              className={
                `no-content text-muted text-center ${noHistoryData ? "" : "hidden"}`
              }
            >
              { I18n.t( "no_observations_yet" ) }
            </div>
            <div id="HistoryChart" className="HistoryChart FrequencyChart"></div>
          </div>
          { fieldValuePanels }
        </div>
      </div>
    );
  }
}

Charts.propTypes = {
  chartedFieldValues: PropTypes.object,
  fetchMonthOfYearFrequency: PropTypes.func,
  fetchMonthFrequency: PropTypes.func,
  openObservationsSearch: PropTypes.func,
  test: PropTypes.string,
  seasonalityColumns: PropTypes.array,
  seasonalityKeys: PropTypes.array,
  historyColumns: PropTypes.array,
  historyKeys: PropTypes.array,
  colors: PropTypes.object
};

Charts.defaultProps = {
  colors: {
    research: "#74ac00",
    verifiable: "#dddddd"
  }
};


export default Charts;
