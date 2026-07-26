import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Alert } from "react-bootstrap";

const AnnotationsMeta = ( { meta, species } ) => {
  if ( _.isEmpty( meta ) ) { return null; }

  const taxonLabel = species
    ? `${species.preferred_common_name || species.name} (${meta.taxon_id})`
    : meta.taxon_id;

  const bits = _.compact( [
    meta.run,
    meta.taxon_id && `conditioned on ${taxonLabel}`,
    meta.taxon_source && `taxon from ${meta.taxon_source}`,
    meta.masked_by_applicability && "applicability-masked",
    meta.ancestry_source && `ancestry from ${meta.ancestry_source}`
  ] );

  return (
    <div className="annotations-meta">
      { meta.off_distribution && (
        <Alert bsStyle="warning">
          <strong>Off distribution.</strong>
          &nbsp;
          This taxon was not well represented in the training data — the
          single-label heads (life stage, sex, alive or dead) degrade most here.
        </Alert>
      ) }
      <div className="meta-line">{ bits.join( " · " ) }</div>
    </div>
  );
};

AnnotationsMeta.propTypes = {
  meta: PropTypes.object,
  species: PropTypes.object
};

export default AnnotationsMeta;
