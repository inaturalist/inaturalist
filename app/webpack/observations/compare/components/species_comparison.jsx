import React, { PropTypes } from "react";
import { OverlayTrigger, Popover } from "react-bootstrap";
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
  setTaxonFilter,
  totalTaxonCounts
} ) => {
  const filteredData = _.filter( taxonFrequencies, row => {
    const frequencies = row.slice( 1, row.length );
    if ( taxonFilter === "common" ) {
      return frequencies.indexOf( 0 ) === -1 && frequencies.indexOf( "?" ) === -1;
    }
    if ( taxonFilter === "not_in_common" ) {
      return frequencies.indexOf( 0 ) >= 0 && frequencies.indexOf( "?" ) === -1;
    }
    if ( taxonFilter === "unique" ) {
      return _.filter( frequencies, f => f > 0 ).length === 1 && frequencies.indexOf( "?" ) === -1;
    }
    return true;
  } );

  return (
    <div className="SpeciesComparison">
      { _.filter( totalTaxonCounts, c => c > 500 ).length > 0 ? (
        <div className="alert alert-danger alert-sm pull-right">
          Some queries missing taxa. <OverlayTrigger
            trigger="click"
            rootClose
            placement="top"
            overlay={ (
              <Popover id="about-missing-taxa" title="About Missing Taxa" className="compare-popover">
                We can only load 500 of the most-observed taxa per query, so if
                there are more taxa represented in the query, they will either not
                appear or show up as "?" if they're present in other
                queries. Try narrowing your queries down so they show 500 taxa or
                less for optimum comparisons.
              </Popover>
            ) }
          >
            <a href="#" onClick={ () => false } className="alert-link">
              <i className="fa fa-info-circle" />
            </a>
          </OverlayTrigger>
        </div>
      ) : null }
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
          title="Taxa observed in all queries"
        >
          { numTaxaInCommon } in common
        </button>
        <button
          className={ `btn btn-${taxonFilter === "not_in_common" ? "primary" : "default"}` }
          onClick={ ( ) => setTaxonFilter( "not_in_common" ) }
          title="Taxa not observed in all queries"
        >
          { numTaxaNotInCommon } not in common
        </button>
        <button
          className={ `btn btn-${taxonFilter === "unique" ? "primary" : "default"}` }
          onClick={ ( ) => setTaxonFilter( "unique" ) }
          title="Taxa observed in only one query"
        >
          { numTaxaUnique } unique
        </button>
      </div>
      <table className="table">
        <thead>
          <tr className="totals">
            <th></th>
            <th className="total-label">
              Total Taxa <OverlayTrigger
                trigger="click"
                rootClose
                placement="top"
                overlay={ (
                  <Popover id="about-total-taxa" title="About Total Taxa" className="compare-popover">
                    This is the total number of "leaf" taxa represented in the
                    query. Sometimes you'll see more rows than this with non-
                    zero counts because there are higher level taxa added from
                    other queries. E.g. if Query 1 has an observation of Homo
                    sapiens and Query 2 has an observation of Genus Homo, both
                    taxa will be present in the table, but that represents one
                    additional  row for Genus Homo for Query 1, which didn't
                    include it in its total count b/c it only counted the
                    species Homo sapiens within that genus, because that was
                    the "leaf" of that part of its tree.
                  </Popover>
                ) }
              >
                <a href="#" onClick={ () => false } className="alert-link">
                  <i className="fa fa-info-circle" />
                </a>
              </OverlayTrigger>
            </th>
            { queries.map( ( query, i ) => (
              <th
                key={ `SpeciesComparison-total-${i}` }
                className={ `value ${totalTaxonCounts[i] && totalTaxonCounts[i] > 500 ? "alert-danger" : ""}` }
                title={
                  `Showing ${parseInt( totalTaxonCounts[i], 0 ) > 500 ? 500 : totalTaxonCounts[i]} of ${totalTaxonCounts[i] || 0}`
                }
              >
                { totalTaxonCounts[i] || "--" }
              </th>
            ) ) }
          </tr>
          <tr className="headers">
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
                  key={ `SpeciesComparison-query-${i}` }
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
              return <tr key={ `row-${i}-${row[0]}` }></tr>;
            }
            return (
              <tr key={ `row-${i}-${row[0]}` }>
                <td>{ i + 1 }</td>
                <td>
                  <SplitTaxon taxon={ taxon } url={`/taxa/${taxon.id}`} />
                </td>
                {
                  _.map( counts, ( count, j ) => {
                    let countUrl = "/observations?";
                    if ( !queries[j] ) {
                      return <td key={ `row-${row[0]}-${j}` }></td>;
                    }
                    countUrl += $.param(
                      Object.assign( $.deparam( ( queries[j] ).params ),
                        { taxon_id: taxon.id }
                      )
                    );
                    let cssClass = "value";
                    if ( allPresent ) {
                      cssClass += " bg-success";
                    } else if ( count === "?" ) {
                      cssClass += " bg-danger";
                    } else if ( _.sum( counts ) === count ) {
                      cssClass += " bg-warning";
                    }
                    return (
                      <td
                        key={ `row-${row[0]}-${j}` }
                        className={ cssClass }
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
  taxonFilter: PropTypes.string,
  totalTaxonCounts: PropTypes.array
};

SpeciesComparison.defaultProps = {
  queries: [],
  taxa: {},
  taxonFrequencies: [],
  totalTaxonCounts: []
};

export default SpeciesComparison;
