import React from "react";
import PropTypes from "prop-types";
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
          { I18n.t( "views.observations.compare.some_queries_missing_taxa" ) }
          { " " }
          <OverlayTrigger
            trigger="click"
            rootClose
            placement="top"
            overlay={(
              <Popover
                id="about-missing-taxa"
                title={I18n.t( "views.observations.about_missing_taxa" )}
                className="compare-popover"
              >
                { I18n.t( "views.observations.compare.some_queries_missing_taxa_desc" )}
              </Popover>
            )}
          >
            <button type="button" onClick={() => false} className="alert-link btn btn-nostyle">
              <i className="fa fa-info-circle" />
            </button>
          </OverlayTrigger>
        </div>
      ) : null }
      <div className="btn-group stacked" role="group" aria-label="species-in-common-controls">
        <button
          type="button"
          className={`btn btn-${!taxonFilter || taxonFilter === "none" ? "primary" : "default"}`}
          onClick={( ) => setTaxonFilter( "none" )}
        >
          { I18n.t( "views.observations.compare.x_total", { count: taxonFrequencies.length } )}
        </button>
        <button
          type="button"
          className={`btn btn-${taxonFilter === "common" ? "primary" : "default"}`}
          onClick={( ) => setTaxonFilter( "common" )}
          title={I18n.t( "views.observations.compare.taxa_observed_in_all_queries" )}
        >
          { I18n.t( "views.observations.compare.x_in_common", { count: numTaxaInCommon } )}
        </button>
        <button
          type="button"
          className={`btn btn-${taxonFilter === "not_in_common" ? "primary" : "default"}`}
          onClick={( ) => setTaxonFilter( "not_in_common" )}
          title={I18n.t( "views.observations.compare.taxa_not_observed_in_all_queries" )}
        >
          { I18n.t( "views.observations.compare.x_not_in_common", { count: numTaxaNotInCommon } )}
        </button>
        <button
          type="button"
          className={`btn btn-${taxonFilter === "unique" ? "primary" : "default"}`}
          onClick={( ) => setTaxonFilter( "unique" )}
          title={I18n.t( "views.observations.compare.taxa_observed_in_only_one_query" )}
        >
          { I18n.t( "views.observations.compare.x_unique", { count: numTaxaUnique } )}
        </button>
      </div>
      <table className="table">
        <thead>
          <tr className="totals">
            <th />
            <th className="total-label">
              { I18n.t( "views.observations.compare.total_taxa" )}
              { " " }
              <OverlayTrigger
                trigger="click"
                rootClose
                placement="top"
                overlay={(
                  <Popover
                    id="about-total-taxa"
                    title={I18n.t( "views.observations.compare.about_total_taxa" )}
                    className="compare-popover"
                  >
                    { I18n.t( "views.observations.compare.total_taxa_desc" )}
                  </Popover>
                )}
              >
                <button type="button" onClick={ () => false } className="alert-link btn btn-nostyle">
                  <i className="fa fa-info-circle" />
                </button>
              </OverlayTrigger>
            </th>
            { queries.map( ( query, i ) => (
              <th
                key={`SpeciesComparison-total-${i}`}
                className={`value ${totalTaxonCounts[i] && totalTaxonCounts[i] > 500 ? "alert-danger" : ""}`}
                title={
                  I18n.t( "showing_x_of_y", {
                    x: parseInt( totalTaxonCounts[i], 0 ) > 500 ? 500 : totalTaxonCounts[i],
                    y: totalTaxonCounts[i] || 0
                  } )
                }
              >
                { totalTaxonCounts[i] || "--" }
              </th>
            ) ) }
          </tr>
          <tr className="headers">
            <th>#</th>
            <th
              className={`sortable taxon ${sortIndex === 0 ? "sorted" : ""}`}
              onClick={( ) => sortFrequenciesByIndex( 0, order === "asc" ? "desc" : "asc" )}
            >
              { I18n.t( "taxon" ) }
            </th>
            { queries.map( ( query, i ) => {
              const queryCol = i + 1;
              let icon;
              if ( sortIndex === queryCol ) {
                icon = order === "asc"
                  ? <i className="fa fa-sort-numeric-asc" />
                  : <i className="fa fa-sort-numeric-desc" />;
              }
              return (
                <th
                  key={`SpeciesComparison-query-${i}`}
                  className={`sortable value ${sortIndex === queryCol ? "sorted" : ""}`}
                  onClick={( ) => sortFrequenciesByIndex( queryCol, sortIndex === queryCol && order === "asc" ? "desc" : "asc" )}
                >
                  { query.name }
                  { " " }
                  <span className="text-muted">{ icon }</span>
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
              return <tr key={`row-${i}-${row[0]}`} />;
            }
            return (
              <tr key={`row-${i}-${row[0]}`}>
                <td>{ i + 1 }</td>
                <td>
                  <SplitTaxon taxon={taxon} url={`/taxa/${taxon.id}`} />
                </td>
                {
                  _.map( counts, ( count, j ) => {
                    let countUrl = "/observations?";
                    if ( !queries[j] ) {
                      return <td key={`row-${row[0]}-${j}`}></td>;
                    }
                    countUrl += $.param(
                      Object.assign( $.deparam( ( queries[j] ).params ),
                        { taxon_id: taxon.id } )
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
                        key={`row-${row[0]}-${j}`}
                        className={cssClass}
                      >
                        <a href={countUrl}>{ count }</a>
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
