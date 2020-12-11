import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import BulletGraph from "./bullet_graph";

const Compare = ( { data, year } ) => {
  const newSpeciesPerYear = _.reduce( data.taxa.accumulation, ( memo, row ) => {
    const y = parseInt( row.date.split( "-" )[0], 0 );
    if ( y > year ) {
      return memo;
    }
    memo[y] = ( memo[y] || 0 ) + row.novel_species_ids.length;
    return memo;
  }, {} );
  const newSpeciesValues = _.values( newSpeciesPerYear );
  const minNewSpeciesValue = _.min( _.values( newSpeciesValues ) );
  const minNewSpeciesYear = _.findKey( newSpeciesPerYear, v => v === minNewSpeciesValue );
  const maxNewSpeciesValue = _.max( _.values( newSpeciesValues ) );
  const maxNewSpeciesYear = _.findKey( newSpeciesPerYear, v => v === maxNewSpeciesValue );
  const speciesPerYear = _.reduce( data.taxa.accumulation, ( memo, row ) => {
    const y = parseInt( row.date.split( "-" )[0], 0 );
    if ( y > year ) {
      return memo;
    }
    memo[y] = ( memo[y] || 0 ) + row.species_count;
    return memo;
  }, {} );
  const speciesValues = _.values( speciesPerYear );
  const minSpeciesValue = _.min( _.values( speciesValues ) );
  const minSpeciesYear = _.findKey( speciesPerYear, v => v === minSpeciesValue );
  const maxSpeciesValue = _.max( _.values( speciesValues ) );
  const maxSpeciesYear = _.findKey( speciesPerYear, v => v === maxSpeciesValue );
  let obsChart;
  if ( data.growth && data.growth.observations ) {
    const obsPerYear = _.reduce( data.growth.observations, ( memo, count, date ) => {
      const y = parseInt( date.split( "-" )[0], 0 );
      if ( y > year ) {
        return memo;
      }
      memo[y] = ( memo[y] || 0 ) + count;
      return memo;
    }, {} );
    const obsValues = _.values( obsPerYear );
    const minObsValue = _.min( _.values( obsValues ) );
    const minObsYear = _.findKey( obsPerYear, v => v === minObsValue );
    const maxObsValue = _.max( _.values( obsValues ) );
    const maxObsYear = _.findKey( obsPerYear, v => v === maxObsValue );
    obsChart = (
      <div className="row stacked">
        <div className="col-xs-12 col-md-2">
          <strong>{ I18n.t( "views.stats.year.observations_per_year" ) }</strong>
          <div className="text-muted">{ I18n.t( "views.stats.year.observations_per_year_by_date_observed" ) }</div>
        </div>
        <div className="col-xs-12 col-md-10">
          <BulletGraph
            performance={obsPerYear[year]}
            comparison={obsPerYear[year - 1]}
            low={minObsValue}
            lowLabel="Min"
            lowLabelExtra={minObsYear}
            medium={_.mean( _.values( obsValues ) )}
            mediumLabel="Mean"
            high={_.max( _.values( obsValues ) )}
            highLabel="Max"
            highLabelExtra={maxObsYear}
          />
        </div>
      </div>
    );
  }
  return (
    <div className="Compare">
      <h3>
        <a name="compare" href="#compare">
          <span>{ I18n.t( "views.stats.year.compared_to_previous_years" ) }</span>
        </a>
      </h3>

      <p className="text-muted">
        { I18n.t( "views.stats.year.compare_desc" ) }
      </p>

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
      <div className="row stacked">
        <div className="col-xs-12 col-md-2">
          <strong>{ I18n.t( "views.stats.year.new_species_per_year" ) }</strong>
          <div className="text-muted">{ I18n.t( "views.stats.year.new_species_per_year_by_date_added" ) }</div>
        </div>
        <div className="col-xs-12 col-md-10">
          <BulletGraph
            performance={newSpeciesPerYear[year]}
            comparison={newSpeciesPerYear[year - 1]}
            low={minNewSpeciesValue}
            lowLabel="Min"
            lowLabelExtra={minNewSpeciesYear}
            medium={_.mean( _.values( newSpeciesValues ) )}
            mediumLabel="Mean"
            high={maxNewSpeciesValue}
            highLabel="Max"
            highLabelExtra={maxNewSpeciesYear}
          />
        </div>
      </div>
      <div className="row stacked">
        <div className="col-xs-12 col-md-2">
          <strong>{ I18n.t( "views.stats.year.species_per_year" ) }</strong>
          <div className="text-muted">{ I18n.t( "views.stats.year.species_per_year_by_date_added" ) }</div>
        </div>
        <div className="col-xs-12 col-md-10">
          <BulletGraph
            performance={speciesPerYear[year]}
            comparison={speciesPerYear[year - 1]}
            low={minSpeciesValue}
            lowLabel="Min"
            lowLabelExtra={minSpeciesYear}
            medium={_.mean( _.values( speciesValues ) )}
            mediumLabel="Mean"
            high={_.max( _.values( speciesValues ) )}
            highLabel="Max"
            highLabelExtra={maxSpeciesYear}
          />
        </div>
      </div>
      { obsChart }
    </div>
  );
};

Compare.propTypes = {
  year: PropTypes.number,
  data: PropTypes.object
};

export default Compare;
