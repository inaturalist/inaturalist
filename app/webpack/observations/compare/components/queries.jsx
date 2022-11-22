import React from "react";
import PropTypes from "prop-types";

const Queries = ( {
  queries,
  addQuery,
  removeQueryAtIndex,
  updateQueryAtIndex,
  updateQueryAtIndexAndFetchData,
  moveQueryUp,
  moveQueryDown
} ) => (
  <div className="Queries form-horizontal">
    { queries.map( ( query, i ) => (
      // eslint-disable-next-line react/no-array-index-key
      <div className="query" key={`query-${i}-${query.params}`}>
        <div className="color" style={{ backgroundColor: query.color }}>
          { query.color }
        </div>
        <input
          type="text"
          defaultValue={query.name}
          className="name form-control"
          placeholder="Label"
          onChange={e => {
            e.target._valueChanged = e.target._lastValue !== e.target.value;
            e.target._lastValue = e.target.value;
          }}
          onBlur={e => {
            if ( e.target._valueChanged ) {
              updateQueryAtIndex( i, { name: e.target.value } );
            }
          }}
        />
        <input
          type="text"
          placeholder="Obs search URL params (everything after ?)"
          defaultValue={query.params}
          className="params form-control"
          onChange={e => {
            e.target._valueChanged = e.target._lastValue !== e.target.value;
            e.target._lastValue = e.target.value;
          }}
          onBlur={e => {
            if ( e.target._valueChanged ) {
              updateQueryAtIndexAndFetchData( i, { params: e.target.value } );
            }
          }}
        />
        <div className="btn-group" role="group" aria-label="Query Actions">
          <button
            type="button"
            className="btn btn-default"
            onClick={( ) => moveQueryUp( i )}
            disabled={i === 0}
          >
            &uarr;
          </button>
          <button
            type="button"
            className="btn btn-default"
            onClick={( ) => moveQueryDown( i )}
            disabled={i === queries.length - 1}
          >
            &darr;
          </button>
          <button
            type="button"
            className="btn btn-warning"
            onClick={( ) => removeQueryAtIndex( i )}
            disabled={queries.length <= 1}
          >
            &times;
          </button>
        </div>
        <button
          type="button"
          className={`btn btn-success ${i < queries.length - 1 ? "invisible" : "visible "}`}
          onClick={( ) => addQuery( )}
        >
          { I18n.t( "add" ) }
        </button>
      </div>
    ) ) }
  </div>
);

Queries.propTypes = {
  queries: PropTypes.array,
  addQuery: PropTypes.func.isRequired,
  removeQueryAtIndex: PropTypes.func.isRequired,
  updateQueryAtIndex: PropTypes.func.isRequired,
  updateQueryAtIndexAndFetchData: PropTypes.func.isRequired,
  moveQueryDown: PropTypes.func.isRequired,
  moveQueryUp: PropTypes.func.isRequired
};

Queries.defaultProps = {
  queries: []
};

export default Queries;
