import React, { PropTypes } from "react";
import _ from "lodash";
import SplitTaxon from "../../../shared/components/split_taxon";

const SpeciesComparison = ( {
  queries,
  taxa,
  taxonFrequencies,
  sortFrequenciesByIndex,
  taxonFrequenciesSortIndex: sortIndex,
  taxonFrequenciesSortOrder: order,
  numTaxaInCommon,
  numTaxaNotInCommon,
  numTaxaUnique,
  taxonFilter,
  setTaxonFilter
} ) => {
  const filteredData = _.filter( taxonFrequencies, row => {
    const frequencies = row.slice( 1, row.length );
    if ( taxonFilter === "in_common" ) {
      return frequencies.indexOf( 0 ) === -1;
    }
    if ( taxonFilter === "not_in_common" ) {
      return frequencies.indexOf( 0 ) >= 0;
    }
    if ( taxonFilter === "unique" ) {
      return _.filter( frequencies, f => f > 0 ).length === 1;
    }
    return true;
  } );
  return (
    <div className="SpeciesComparison">
      <div className="btn-group stacked" role="group" aria-label="species-in-common-controls">
        <button
          className={ `btn btn-${!taxonFilter || taxonFilter === "none" ? "primary" : "default"}` }
          onClick={ ( ) => setTaxonFilter( "none" ) }
        >
          { taxonFrequencies.length } total
        </button>
        <button
          className={ `btn btn-${taxonFilter === "common" ? "primary" : "default"}` }
          onClick={ ( ) => setTaxonFilter( "common" ) }
        >
          { numTaxaInCommon } in common
        </button>
        <button
          className={ `btn btn-${taxonFilter === "not_in_common" ? "primary" : "default"}` }
          onClick={ ( ) => setTaxonFilter( "not_in_common" ) }
        >
          { numTaxaNotInCommon } not in common
        </button>
        <button
          className={ `btn btn-${taxonFilter === "unique" ? "primary" : "default"}` }
          onClick={ ( ) => setTaxonFilter( "unique" ) }
        >
          { numTaxaUnique } unique
        </button>
      </div>
      <table className="table">
        <thead>
          <tr>
            <th>#</th>
            <th
              className={ `sortable taxon ${sortIndex === 0 ? "sorted" : ""}` }
              onClick={ ( ) => sortFrequenciesByIndex( 0, order === "asc" ? "desc" : "asc" ) }
            >
              { I18n.t( "taxon" ) }
            </th>
            { queries.map( ( query, i ) => {
              const queryCol = i + 1;
              let icon;
              if ( sortIndex === queryCol ) {
                icon = order === "asc" ? <i className="fa fa-sort-numeric-asc"></i> : <i className="fa fa-sort-numeric-desc"></i>;
              }
              return (
                <th
                  key={ `query-${i}` }
                  className={ `sortable value ${sortIndex === queryCol ? "sorted" : ""}` }
                  onClick={ ( ) => sortFrequenciesByIndex( queryCol, sortIndex === queryCol && order === "asc" ? "desc" : "asc" ) }
                >
                  { query.name } <span className="text-muted">{ icon }</span>
                </th>
              );
            } ) }
          </tr>
        </thead>
        <tbody>
          { filteredData.map( ( row, i ) => {
            const counts = row.slice( 1, row.length );
            const allPresent = _.filter( counts, c => c > 0 ).length === counts.length;
            const taxon = taxa[row[0]];
            if ( !taxon ) {
              return <tr></tr>;
            }
            return (
              <tr key={ `row-${row[0]}` }>
                <td>{ i + 1 }</td>
                <td>
                  <SplitTaxon taxon={ taxon } url={`/taxa/${taxon.id}`} />
                </td>
                {
                  _.map( counts, ( count, j ) => {
                    let countUrl = "/observations?";
                    countUrl += $.param(
                      Object.assign( $.deparam( ( queries[j] || {} ).params ),
                        { taxon_id: taxon.id }
                      )
                    );
                    return (
                      <td
                        key={ `row-${row[0]}-${j}` }
                        className={ `value ${allPresent ? "bg-success" : ""}` }
                      >
                        <a href={ countUrl }>{ count }</a>
                      </td>
                    );
                  } )
                }
              </tr>
            );
          } ) }
        </tbody>
      </table>
    </div>
  );
};

SpeciesComparison.propTypes = {
  queries: PropTypes.array,
  taxa: PropTypes.object,
  taxonFrequencies: PropTypes.array,
  taxonFrequenciesSortIndex: PropTypes.number,
  taxonFrequenciesSortOrder: PropTypes.string,
  sortFrequenciesByIndex: PropTypes.func,
  numTaxaInCommon: PropTypes.number,
  numTaxaNotInCommon: PropTypes.number,
  numTaxaUnique: PropTypes.number,
  setTaxonFilter: PropTypes.func,
  taxonFilter: PropTypes.string
};

SpeciesComparison.defaultProps = {
  queries: [],
  taxa: {},
  taxonFrequencies: []
};

export default SpeciesComparison;
