import React, { Component } from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import BulletGraph from "./bullet_graph";

class Compare extends Component {
  constructor( props ) {
    super( props );
    this.state = {
      dateField: props.dateField
    };
  }

  render( ) {
    const { data, year, forUser } = this.props;
    const { dateField } = this.state;
    const taxaAccumulation = (
      dateField === "observed_on"
      && data.taxa.accumulation_by_date_observed
    )
      ? data.taxa.accumulation_by_date_observed
      : data.taxa.accumulation;
    const newSpeciesPerYear = _.reduce( taxaAccumulation, ( memo, row ) => {
      const y = parseInt( row.date.split( "-" )[0], 0 );
      if ( y > year ) {
        return memo;
      }
      memo[y] = ( memo[y] || 0 ) + row.novel_species_ids.length;
      return memo;
    }, {} );
    const speciesPerYear = _.reduce( taxaAccumulation, ( memo, row ) => {
      const y = parseInt( row.date.split( "-" )[0], 0 );
      if ( y > year ) {
        return memo;
      }
      memo[y] = ( memo[y] || 0 ) + row.species_count;
      return memo;
    }, {} );
    // If there's only one year represented, there's nothing to compare
    if ( _.keys( speciesPerYear ).length < 2 ) {
      // return <div />;
    }
    if ( year < 2020 ) {
      return <div />;
    }
    const newSpeciesValues = _.filter( _.values( newSpeciesPerYear ), v => v > 0 );
    const minNewSpeciesValue = _.min( newSpeciesValues );
    const minNewSpeciesYear = _.findKey( newSpeciesPerYear, v => v === minNewSpeciesValue );
    const maxNewSpeciesValue = _.max( newSpeciesValues );
    const maxNewSpeciesYear = _.findKey( newSpeciesPerYear, v => v === maxNewSpeciesValue );
    const speciesValues = _.filter( _.values( speciesPerYear ), v => v > 0 );
    const minSpeciesValue = _.min( speciesValues );
    const minSpeciesYear = _.findKey( speciesPerYear, v => v === minSpeciesValue );
    const maxSpeciesValue = _.max( speciesValues );
    const maxSpeciesYear = _.findKey( speciesPerYear, v => v === maxSpeciesValue );
    let obsChart;
    const obsMonths = (
      dateField === "observed_on"
      && data.observations
      && data.observations.month_histogram
    )
      ? data.observations.month_histogram
      : data.growth.observations;
    if ( obsMonths ) {
      const obsPerYear = _.reduce( obsMonths, ( memo, count, date ) => {
        const y = parseInt( date.split( "-" )[0], 0 );
        if ( y > year ) {
          return memo;
        }
        memo[y] = ( memo[y] || 0 ) + count;
        return memo;
      }, {} );
      const obsValues = _.filter( _.values( obsPerYear ), v => v > 0 );
      const minObsValue = _.min( obsValues );
      const minObsYear = _.findKey( obsPerYear, v => v === minObsValue );
      const maxObsValue = _.max( obsValues );
      const maxObsYear = _.findKey( obsPerYear, v => v === maxObsValue );
      obsChart = (
        <div className="row stacked">
          <div className="col-xs-12 col-md-2">
            <strong>{ I18n.t( "views.stats.year.observations_per_year" ) }</strong>
            <div className="text-muted">
              { dateField === "created_at"
                ? I18n.t( "views.stats.year.observations_per_year_by_date_added" )
                : I18n.t( "views.stats.year.observations_per_year_by_date_observed" )
              }
            </div>
          </div>
          <div className="col-xs-12 col-md-10">
            <BulletGraph
              performance={obsPerYear[year]}
              comparison={obsPerYear[year - 1]}
              low={minObsValue}
              lowLabel={I18n.t( "low" )}
              lowLabelExtra={minObsYear}
              medium={_.mean( obsValues )}
              mediumLabel={I18n.t( "avg" )}
              high={_.max( obsValues )}
              highLabel={I18n.t( "high" )}
              highLabelExtra={maxObsYear}
            />
          </div>
        </div>
      );
    }
    return (
      <div className="Compare">
        <h3>
          <a id="compare" name="compare" href="#compare">
            <span>{ I18n.t( "views.stats.year.compared_to_previous_years" ) }</span>
          </a>
        </h3>

        { forUser && (
          <p className="text-muted">
            { I18n.t( "views.stats.year.compare_desc" ) }
          </p>
        ) }

        <div className="legend-controls">
          <div className="legend">
            <div className="legend-item">
              <div className="legend-mark this-year" />
              { year }
            </div>
            <div className="legend-item">
              <div className="legend-mark last-year" />
              { year - 1 }
            </div>
          </div>
          { data.taxa.accumulation_by_date_observed && (
            <div className="controls">
              <div className="btn-group" data-toggle="buttons">
                <button
                  className={`btn btn-inat ${this.state.dateField === "created_at" ? "active" : ""}`}
                  type="button"
                  onClick={() => this.setState( { dateField: "created_at" } )}
                >
                  { I18n.t( "date_added" ) }
                </button>
                <button
                  className={`btn btn-inat ${this.state.dateField === "observed_on" ? "active" : ""}`}
                  type="button"
                  onClick={() => this.setState( { dateField: "observed_on" } )}
                >
                  { I18n.t( "date_observed_" ) }
                </button>
              </div>
            </div>
          ) }
        </div>
        <div className="row stacked">
          <div className="col-xs-12 col-md-2">
            <strong>{ I18n.t( "views.stats.year.new_species_per_year" ) }</strong>
            <div className="text-muted">
              { dateField === "created_at"
                ? I18n.t( "views.stats.year.new_species_per_year_by_date_added" )
                : I18n.t( "views.stats.year.new_species_per_year_by_date_observed" )
              }
            </div>
          </div>
          <div className="col-xs-12 col-md-10">
            <BulletGraph
              performance={newSpeciesPerYear[year]}
              comparison={newSpeciesPerYear[year - 1]}
              low={minNewSpeciesValue}
              lowLabel={I18n.t( "low" )}
              lowLabelExtra={minNewSpeciesYear}
              medium={_.mean( newSpeciesValues )}
              mediumLabel={I18n.t( "avg" )}
              high={maxNewSpeciesValue}
              highLabel={I18n.t( "high" )}
              highLabelExtra={maxNewSpeciesYear}
            />
          </div>
        </div>
        <div className="row stacked">
          <div className="col-xs-12 col-md-2">
            <strong>{ I18n.t( "views.stats.year.species_per_year" ) }</strong>
            <div className="text-muted">
              { dateField === "created_at"
                ? I18n.t( "views.stats.year.species_per_year_by_date_added" )
                : I18n.t( "views.stats.year.species_per_year_by_date_observed" )
              }
            </div>
          </div>
          <div className="col-xs-12 col-md-10">
            <BulletGraph
              performance={speciesPerYear[year]}
              comparison={speciesPerYear[year - 1]}
              low={minSpeciesValue}
              lowLabel={I18n.t( "low" )}
              lowLabelExtra={minSpeciesYear}
              medium={_.mean( speciesValues )}
              mediumLabel={I18n.t( "avg" )}
              high={_.max( speciesValues )}
              highLabel={I18n.t( "high" )}
              highLabelExtra={maxSpeciesYear}
            />
          </div>
        </div>
        { obsChart }
      </div>
    );
  }
}

Compare.propTypes = {
  year: PropTypes.number.isRequired,
  data: PropTypes.object.isRequired,
  dateField: PropTypes.oneOf( ["created_at", "observed_on"] ),
  forUser: PropTypes.bool
};

Compare.defaultProps = {
  dateField: "created_at",
  forUser: false
};

export default Compare;
