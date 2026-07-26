import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

const AnnotationsTable = ( { annotations } ) => {
  const rowCount = _.max( _.map( annotations, a => ( a.applicable ? a.values.length : 1 ) ) ) || 0;

  const cellFor = ( attribute, rowIndex ) => {
    if ( !attribute.applicable ) {
      return rowIndex === 0
        ? <div className="not-applicable-cell">not applicable to this taxon</div>
        : null;
    }
    const value = attribute.values[rowIndex];
    if ( !value ) { return null; }
    const classes = ["value-cell"];
    if ( value.predicted ) {
      classes.push( "predicted" );
    } else {
      classes.push( "dim" );
    }
    const title = value.threshold
      ? `${value.label}: ${value.score} (threshold ${value.threshold})`
      : `${value.label}: ${value.score}`;
    return (
      <div title={title}>
        <div className={classes.join( " " )}>
          <span className="value-label">{ value.label }</span>
          <span className="value-score">{ _.round( value.score, 3 ).toFixed( 3 ) }</span>
        </div>
        <div className={`score-bar${value.predicted ? " predicted" : ""}`}>
          <div style={{ width: `${_.clamp( value.score, 0, 1 ) * 100}%` }} />
        </div>
      </div>
    );
  };

  return (
    <table className="table annotations-table">
      <thead>
        <tr>
          { annotations.map( attribute => (
            <th
              key={`head-${attribute.name}`}
              className={attribute.applicable ? "" : "not-applicable"}
            >
              { attribute.label }
              <span className="head-type">
                { attribute.type === "ce" ? "single value" : "multiple values" }
              </span>
            </th>
          ) ) }
        </tr>
      </thead>
      <tbody>
        { _.times( rowCount, rowIndex => (
          <tr key={`row-${rowIndex}`}>
            { annotations.map( attribute => (
              <td key={`cell-${attribute.name}-${rowIndex}`}>
                { cellFor( attribute, rowIndex ) }
              </td>
            ) ) }
          </tr>
        ) ) }
      </tbody>
    </table>
  );
};

AnnotationsTable.propTypes = {
  annotations: PropTypes.array.isRequired
};

export default AnnotationsTable;
