import React, { PropTypes } from "react";

const Queries = ( {
  queries,
  addQuery,
  removeQueryAtIndex,
  updateQueryAtIndex,
  moveQueryUp,
  moveQueryDown
} ) => (
  <div className="Queries form-horizontal">
    { queries.map( ( query, i ) => (
      <div className="query" key={ `query-${i}-${query.params}` }>
        <input
          type="text"
          defaultValue={ query.name }
          className="name form-control"
          placeholder="Label"
          onBlur={ e => {
            updateQueryAtIndex( i, { name: e.target.value } );
          } }
        />
        <input
          type="text"
          placeholder="Obs search URL params (everything after ?)"
          defaultValue={ query.params }
          className="params form-control"
          onBlur={ e => {
            updateQueryAtIndex( i, { params: e.target.value } );
          } }
        />
        <div className="btn-group" role="group" aria-label="Query Actions">
          <button
            className="btn btn-default"
            onClick={ ( ) => moveQueryUp( i ) }
            disabled={ i === 0 }
          >
            &uarr;
          </button>
          <button
            className="btn btn-default"
            onClick={ ( ) => moveQueryDown( i ) }
            disabled={ i === queries.length - 1 }
          >
            &darr;
          </button>
          <button
            className="btn btn-warning"
            onClick={ ( ) => removeQueryAtIndex( i ) }
            disabled={ queries.length <= 1 }
          >
            &times;
          </button>
        </div>
        <button
          className={ `btn btn-success ${i < queries.length - 1 ? "invisible" : "visible "}` }
          onClick={ ( ) => addQuery( ) }
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
  moveQueryDown: PropTypes.func.isRequired,
  moveQueryUp: PropTypes.func.isRequired
};

Queries.defaultProps = {
  queries: []
};

export default Queries;
