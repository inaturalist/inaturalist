import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import c3 from "c3";
import moment from "moment";

class Charts extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    this.renderSeasonalityChart( );
    $( "a[data-toggle=tab]", domNode ).on( "shown.bs.tab", e => {
      switch ( e.target.hash ) {
        case "#charts-seasonality":
          if ( this.seasonalityChart ) {
            this.seasonalityChart.flush( );
          }
          break;
        case "#charts-history":
          if ( !_.isEmpty( this.props.historyColumns ) ) {
            this.props.fetchMonthFrequency( );
          }
          if ( this.historyChart ) {
            this.historyChart.flush( );
          }
          break;
        default:
          // it's cool, you probably have what you need
      }
    } );
  }
  shouldComponentUpdate( nextProps ) {
    if (
      _.isEqual(
        this.objectToComparable( this.props.seasonalityColumns ),
        this.objectToComparable( nextProps.seasonalityColumns )
      )
      &&
      _.isEqual(
        this.objectToComparable( this.props.historyColumns ),
        this.objectToComparable( nextProps.historyColumns )
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
  }
  defaultC3Config( ) {
    return {
      data: {
        colors: this.props.colors,
        types: {
          verifiable: "line",
          research: "area"
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
  objectToComparable( object = {} ) {
    return _.map( object, ( v, k ) => {
      if ( _.isArrayLikeObject( v ) ) {
        return `(${k}-${this.objectToComparable( v )})`;
      }
      return `(${k}-${v})`;
    } ).sort( ).join( "," );
  }
  tooltipContent( data, defaultTitleFormat, defaultValueFormat, color, tipTitle ) {
    const order = [
      "research",
      "verifiable",
      "Flowering Phenology=bare",
      "Flowering Phenology=budding",
      "Flowering Phenology=flower",
      "Flowering Phenology=fruit",
      "Insect life stage=egg",
      "Insect life stage=larva",
      "Insect life stage=teneral",
      "Insect life stage=nymph",
      "Insect life stage=pupa",
      "Insect life stage=adult"
    ];
    const tipRows = order.map( seriesName => {
      const item = _.find( data, series => series.name === seriesName );
      if ( item ) {
        return `
          <div class="series">
            <span class="swatch" style="background-color: ${color( item )}"></span>
            <span class="column-label">${I18n.t( `views.taxa.show.frequency.${item.name}` )}:</span>
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
  renderSeasonalityChart( ) {
    const that = this;
    const config = _.defaultsDeep( { }, this.defaultC3Config( ), {
      data: {
        columns: this.props.seasonalityColumns,
        onclick: d => {
          that.seasonalityChart.unselect( ["verifiable", "research"] );
          that.props.openObservationsSearch( {
            month: d.x + 1
          } );
        }
      },
      axis: {
        x: {
          type: "category",
          categories: this.props.seasonalityKeys.map( i => I18n.t( "date.abbr_month_names" )[i].toUpperCase( ) )
        }
      },
      tooltip: {
        contents: ( d, defaultTitleFormat, defaultValueFormat, color ) => that.tooltipContent(
          d, defaultTitleFormat, defaultValueFormat, color,
          `${I18n.t( "observations_total" )}: ${I18n.t( "date.month_names" )[d[0].index + 1]}`
        )
      }
    } );
    const mountNode = $( ".SeasonalityChart", ReactDOM.findDOMNode( this ) ).get( 0 );
    this.seasonalityChart = c3.generate( Object.assign( { bindto: mountNode }, config ) );
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
            <div className="SeasonalityChart FrequencyChart">
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
            <div className="HistoryChart FrequencyChart"></div>
          </div>
        </div>
      </div>
    );
  }
}

Charts.propTypes = {
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
    verifiable: "#dddddd",
    "Flowering Phenology=bare": "#fecc5c",
    "Flowering Phenology=budding": "#f03b20",
    "Flowering Phenology=flower": "#bd0026",
    "Flowering Phenology=fruit": "#fd8d3c",
    "Insect life stage=egg": "#d4b9da",
    "Insect life stage=larva": "#c994c7",
    "Insect life stage=teneral": "#df65b0",
    "Insect life stage=nymph": "#e7298a",
    "Insect life stage=pupa": "#ce1256",
    "Insect life stage=adult": "#91003f"
  }
};


export default Charts;
