/* global I18n */

import React from "react";
import PropTypes from "prop-types";

const SummaryFeedback = ( {
  options = [],
  userVote = {},
  onVote,
  canVote = false,
  pendingMetrics = {},
  loading = false,
  message = null
} ) => (
  <div className="fg-feedback-card">
    {loading ? (
      <div className="fg-subtle">
        {I18n.t( "id_summaries.demo.summary_feedback.loading" )}
      </div>
    ) : null}
    <p className="fg-feedback-explainer">
      {I18n.t( "id_summaries.demo.summary_feedback.explainer" )}
    </p>
    {message ? <div className="fg-feedback-note">{message}</div> : null}
    <ul className="fg-feedback-options">
      {options.map( option => {
        const voteState = userVote?.[option.key] || 0;
        const pending = !!pendingMetrics?.[option.key];
        const canSubmit = typeof onVote === "function" && canVote && !pending;
        const disableReason = !canVote
          ? I18n.t( "id_summaries.demo.summary_feedback.sign_in_tooltip" )
          : pending
            ? I18n.t( "id_summaries.demo.summary_feedback.submitting_tooltip" )
            : undefined;
        return (
          <li key={option.key || option.label} className="fg-feedback-option">
            <span className="fg-feedback-option-label">{option.label}</span>
            <span className="fg-feedback-option-votes">
              <button
                type="button"
                className={`fg-feedback-thumb up${voteState === 1 ? " active" : ""}${pending ? " pending" : ""}`}
                onClick={() => ( canSubmit ? onVote( option.key, 1 ) : null )}
                disabled={!canSubmit}
                aria-pressed={voteState === 1}
                aria-label={
                  I18n.t( "id_summaries.demo.summary_feedback.aria_helpful", {
                    label: option.label
                  } )
                }
                title={disableReason}
              >
                <span aria-hidden="true" className="fg-feedback-icon">
                  <i className="fa fa-thumbs-o-up fg-feedback-icon--outline" />
                  <i className="fa fa-thumbs-up fg-feedback-icon--solid" />
                </span>
                <span
                  className={`fg-feedback-count${option.up > 0 ? "" : " is-hidden"}`}
                  aria-hidden={option.up <= 0}
                >
                  {option.up}
                </span>
              </button>
              <button
                type="button"
                className={`fg-feedback-thumb down${voteState === -1 ? " active" : ""}${pending ? " pending" : ""}`}
                onClick={() => ( canSubmit ? onVote( option.key, -1 ) : null )}
                disabled={!canSubmit}
                aria-pressed={voteState === -1}
                aria-label={
                  I18n.t( "id_summaries.demo.summary_feedback.aria_not_helpful", {
                    label: option.label
                  } )
                }
                title={disableReason}
              >
                <span aria-hidden="true" className="fg-feedback-icon">
                  <i className="fa fa-thumbs-o-down fg-feedback-icon--outline" />
                  <i className="fa fa-thumbs-down fg-feedback-icon--solid" />
                </span>
                <span
                  className={`fg-feedback-count${option.down > 0 ? "" : " is-hidden"}`}
                  aria-hidden={option.down <= 0}
                >
                  {option.down}
                </span>
              </button>
            </span>
          </li>
        );
      } )}
    </ul>
  </div>
);

export default SummaryFeedback;

SummaryFeedback.propTypes = {
  options: PropTypes.arrayOf( PropTypes.shape( {
    key: PropTypes.string,
    label: PropTypes.string,
    up: PropTypes.number,
    down: PropTypes.number
  } ) ),
  userVote: PropTypes.objectOf( PropTypes.number ),
  onVote: PropTypes.func,
  canVote: PropTypes.bool,
  pendingMetrics: PropTypes.objectOf( PropTypes.bool ),
  loading: PropTypes.bool,
  message: PropTypes.string
};
