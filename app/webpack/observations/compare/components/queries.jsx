import React, { PropTypes } from "react";

const Queries = ( {
  queries,
  addQuery,
  removeQueryAtIndex,
  updateQueryAtIndex
} ) => (
  <div className="Queries form-horizontal">
    { queries.map( ( query, i ) => (
      <div className="query" key={ `query-${i}` }>
        <input
          type="text"
          defaultValue={ query.name }
          className="name form-control"
          onBlur={ e => {
            updateQueryAtIndex( i, { name: e.target.value } );
          } }
        />
        <input
          type="text"
          defaultValue={ query.params }
          className="params form-control"
          onBlur={ e => {
            updateQueryAtIndex( i, { params: e.target.value } );
          } }
        />
        <button
          className="btn btn-warning"
          onClick={ ( ) => removeQueryAtIndex( i ) }
          disabled={ queries.length <= 1 }
        >
          &times;
        </button>
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
  updateQueryAtIndex: PropTypes.func.isRequired
};

Queries.defaultProps = {
  queries: []
};

export default Queries;
