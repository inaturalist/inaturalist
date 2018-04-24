import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import c3 from "c3";
import moment from "moment";
import { Modal } from "react-bootstrap";
import { objectToComparable } from "../../../shared/util";

class Charts extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      helpModalVisible: false
    };
  }
  componentDidMount( ) {
    this.renderSeasonalityChart( );
    this.resetChartTabEvents( );
  }
  shouldComponentUpdate( nextProps, nextState ) {
    if (
      this.props.scaled === nextProps.scaled
      &&
      _.isEqual(
        objectToComparable( this.props.seasonalityColumns ),
        objectToComparable( nextProps.seasonalityColumns )
      )
      &&
      _.isEqual(
        objectToComparable( this.props.historyColumns ),
        objectToComparable( nextProps.historyColumns )
      )
      &&
      _.isEqual(
        objectToComparable( this.state ),
        objectToComparable( nextState )
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
  showHelpModal( ) {
    this.setState( { helpModalVisible: true } );
  }
  hideHelpModal( ) {
    this.setState( { helpModalVisible: false } );
  }
  formatNumber( number ) {
    const precision = this.props.scaled ? 4 : 0;
    if ( number > 0 && number < 0.0001 ) {
      return number.toExponential( 2 );
    }
    if ( number > 9999 ) {
      return number.toExponential( precision );
    }
    return I18n.toNumber( number, { precision } );
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
            format: d => this.formatNumber( d )
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
    const items = _.compact( order.map( seriesName => _.find( data, series => series.name === seriesName ) ) );
    const unAnnotatedItem = _.find( data, d => d.id === "unannotated" );
    if ( unAnnotatedItem ) {
      items.push( unAnnotatedItem );
    }
    const tipRows = items.map( item => `
      <div class="series">
        <span class="swatch" style="background-color: ${color( item )}"></span>
        <span class="column-label">
          ${
            I18n.t( `views.taxa.show.frequency.${item.name}`, {
              defaultValue: item.name.split( "=" )[1]
            } )
          }:
        </span>
        <span class="value">
          ${this.formatNumber( item.value )}
        </span>
      </div>
    ` );
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
    let tipTitle = I18n.t( "observations_total" );
    if ( that.props.scaled ) {
      tipTitle = I18n.t( "relative_observations" );
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
          `${tipTitle}: ${I18n.t( "date.month_names" )[d[0].index + 1]}`
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
        _.startsWith( column[0], `${values[0].controlled_attribute.label}=` )
      );
      const verifiableColumn = _.find( this.props.seasonalityColumns, c => c[0] === "verifiable" );
      if ( verifiableColumn ) {
        const unAnnotatedColumn = verifiableColumn.slice( 0 );
        unAnnotatedColumn[0] = "unannotated";
        _.each( columns, column => {
          for ( let i = 1; i < column.length; i++ ) {
            unAnnotatedColumn[i] = unAnnotatedColumn[i] - column[i];
          }
        } );
        columns.unshift( unAnnotatedColumn );
      }
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
        Object.assign( { bindto: mountNode }, config )
      );
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
    let tipTitle = I18n.t( "observations_total" );
    if ( that.props.scaled ) {
      tipTitle = I18n.t( "relative_observations" );
    }
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
          `${tipTitle}:
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
    const {
      chartedFieldValues,
      config,
      historyKeys,
      scaled,
      seasonalityKeys,
      setScaledPreference,
      taxon
    } = this.props;
    const noHistoryData = _.isEmpty( historyKeys );
    const noSeasonalityData = _.isEmpty( seasonalityKeys );
    let fieldValueTabs = [];
    let fieldValuePanels = [];
    if ( chartedFieldValues ) {
      _.each( chartedFieldValues, ( values, termID ) => {
        fieldValueTabs.push( (
          <li role="presentation" key={ `charts-field-values-${termID}` }>
            <a
              href={ `#charts-field-values-${termID}` }
              aria-controls={ `charts-field-values-${termID}` }
              role="tab"
              data-toggle="tab"
            >
              { I18n.t( `controlled_term_labels.${_.snakeCase( values[0].controlled_attribute.label )}`,
                { defaultValue: values[0].controlled_attribute.label } ) }
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
          <li role="presentation" className="pull-right">
            <div className="dropdown inlineblock">
              <button
                className="btn btn-link help-btn dropdown-toggle"
                type="button"
                data-toggle="dropdown"
                aria-haspopup="true"
                aria-expanded="false"
              >
                <i className="fa fa-gear"></i>
              </button>
              <ul className="dropdown-menu dropdown-menu-right">
                <li>
                  { scaled ? (
                    <a
                      href="#"
                      onClick={ e => {
                        e.preventDefault( );
                        setScaledPreference( false );
                        return false;
                      } }
                    >
                      { I18n.t( "show_total_counts" ) }
                    </a>
                  ) : (
                    <a
                      href="#"
                      onClick={ e => {
                        e.preventDefault( );
                        setScaledPreference( true );
                        return false;
                      } }
                    >
                      { I18n.t( "show_relative_proportions_of_all_observations" ) }
                    </a>
                  ) }
                </li>
                { chartedFieldValues && config && config.currentUser && config.currentUser.id ? (
                  _.map( this.props.chartedFieldValues, ( values, termID ) => (
                    <li key={ `identify-link-for-${termID}` }>
                      <a
                        href={
                          `/observations/identify?taxon_id=${taxon.id}&without_term_id=${termID}&reviewed=any&quality_grade=needs_id,research`
                        }
                        target="_blank"
                      >
                        {
                          I18n.t( `add_annotations_for_controlled_attribute.${_.snakeCase( values[0].controlled_attribute.label )}`, {
                            defaultValue: I18n.t( "add_annotations_for_x", {
                              x: I18n.t( `controlled_term_labels.${_.snakeCase( values[0].controlled_attribute.label )}` )
                            } )
                          } )
                        }
                      </a>
                    </li>
                  ) )
                ) : null }
              </ul>
            </div>
            <button
              className="btn btn-link help-btn"
              onClick={ ( ) => this.showHelpModal( ) }
            >
              <i className="fa fa-question-circle"></i>
            </button>
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
        <Modal
          id="ChartsHelpModal"
          show={ this.state.helpModalVisible }
          onHide={ ( ) => this.hideHelpModal( ) }
        >
          <Modal.Header closeButton>
            <Modal.Title>{ I18n.t( "about_charts" ) }</Modal.Title>
          </Modal.Header>
          <Modal.Body>
            <h4>{ I18n.t( "seasonality" ) }</h4>
            <p>
              { I18n.t( "views.taxa.show.charts_help_seasonality" ) }
            </p>
            <h4>{ I18n.t( "history" ) }</h4>
            <p>
              { I18n.t( "views.taxa.show.charts_help_history" ) }
            </p>
            <h4>{ I18n.t( "relative_observations" ) }</h4>
            <p>
              { I18n.t( "views.taxa.show.charts_help_relative_observations" ) }
            </p>
            <h4>{ I18n.t( "other" ) }</h4>
            <p>
              { I18n.t( "views.taxa.show.charts_help_other" ) }
            </p>
          </Modal.Body>
        </Modal>
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
  colors: PropTypes.object,
  scaled: PropTypes.bool,
  setScaledPreference: PropTypes.func,
  taxon: PropTypes.object,
  config: PropTypes.object
};

Charts.defaultProps = {
  colors: {
    research: "#74ac00",
    verifiable: "#dddddd",
    unannotated: "#dddddd"
  }
};


export default Charts;
