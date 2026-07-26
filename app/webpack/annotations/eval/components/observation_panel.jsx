import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Glyphicon, Button } from "react-bootstrap";
import TaxonAutocomplete from "../../../observations/uploader/components/taxon_autocomplete";

const ObservationPanel = ( {
  obsCard,
  species,
  speciesSource,
  visionSpecies,
  status,
  setSpecies,
  revertSpecies,
  resetState
} ) => {
  const locationText = obsCard.localityNotes
    || (
      obsCard.latitude
      && `${_.round( obsCard.latitude, 4 )}, ${_.round( obsCard.longitude, 4 )}`
    )
    || "";

  let speciesHint;
  if ( status === "loading" && !species ) {
    speciesHint = "Inferring species from the vision model…";
  } else if ( status === "failed" ) {
    speciesHint = "The vision model could not be reached — pick a species manually.";
  } else if ( speciesSource === "manual" ) {
    speciesHint = (
      <span>
        Overriding the inferred species.
        { visionSpecies && (
          <Button bsStyle="link" onClick={revertSpecies}>
            { `revert to ${visionSpecies.preferred_common_name || visionSpecies.name}` }
          </Button>
        ) }
      </span>
    );
  } else if ( species ) {
    speciesHint = "Inferred by the vision model. Change it to re-score against another taxon.";
  } else {
    speciesHint = "No species inferred — the taxon vector will be all zeros.";
  }

  return (
    <div className="observation-panel">
      <button
        type="button"
        className="btn-close"
        title="Reset"
        aria-label="Reset"
        onClick={resetState}
      >
        <Glyphicon glyph="remove" />
      </button>
      <div className="photo">
        { obsCard.photoPreview
          ? <img src={obsCard.photoPreview} alt={obsCard.name || "Photo being evaluated"} />
          : <div className="loading_spinner" /> }
      </div>
      <div className="fields">
        { obsCard.observationID && (
          <div className="field">
            <label htmlFor="annotation-eval-observation">Observation</label>
            <a
              id="annotation-eval-observation"
              href={`/observations/${obsCard.observationID}`}
              target="_blank"
              rel="noopener noreferrer"
            >
              { obsCard.observationID }
            </a>
          </div>
        ) }
        <div className="field">
          <label htmlFor="annotation-eval-date">Date</label>
          <input
            id="annotation-eval-date"
            type="text"
            className="form-control input-sm"
            value={obsCard.date || ""}
            placeholder="No date"
            readOnly
          />
        </div>
        <div className="field">
          <label htmlFor="annotation-eval-location">Location</label>
          <input
            id="annotation-eval-location"
            type="text"
            className="form-control input-sm"
            value={locationText}
            placeholder="No location"
            readOnly
          />
        </div>
        <div className="field taxon-autocomplete-field">
          <label htmlFor="taxon_name">Species</label>
          <TaxonAutocomplete
            small
            bootstrap
            searchExternal
            showPlaceholder
            perPage={6}
            initialTaxonID={species ? species.id : null}
            afterSelect={r => setSpecies( r.item )}
            afterUnselect={( ) => setSpecies( null )}
          />
          <div className="hint">{ speciesHint }</div>
        </div>
      </div>
    </div>
  );
};

ObservationPanel.propTypes = {
  obsCard: PropTypes.object.isRequired,
  species: PropTypes.object,
  speciesSource: PropTypes.string,
  visionSpecies: PropTypes.object,
  status: PropTypes.string,
  setSpecies: PropTypes.func,
  revertSpecies: PropTypes.func,
  resetState: PropTypes.func
};

export default ObservationPanel;
