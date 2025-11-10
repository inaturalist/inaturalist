/* global I18n */

import React, {
  useCallback,
  useEffect,
  useMemo,
  useState
} from "react";
import PropTypes from "prop-types";
import inatjs from "inaturalistjs";
import {
  hasReferenceMetrics,
  referenceMetricKeys,
  referenceMetricLabel,
  buildEmptyReferenceMetricCounts,
  fetchReferenceMetricsCounts
} from "../util/reference_metrics";

const ReferenceFeedback = ( {
  reference,
  summaryId,
  speciesUuid,
  speciesLabel,
  children
} ) => {
  const referenceId = reference?.id;
  const [isOpen, setIsOpen] = useState( false );
  const [metricsState, setMetricsState] = useState( {
    counts: buildEmptyReferenceMetricCounts(),
    userVote: {}
  } );
  const [loading, setLoading] = useState( false );
  const [error, setError] = useState( null );
  const [pendingMetrics, setPendingMetrics] = useState( {} );
  const [hasLoaded, setHasLoaded] = useState( false );

  const currentUserId = useMemo( ( ) => (
    typeof window !== "undefined"
    && window.CURRENT_USER
    && window.CURRENT_USER.id
  ) || null, [] );

  useEffect( ( ) => {
    setIsOpen( false );
    setMetricsState( {
      counts: buildEmptyReferenceMetricCounts(),
      userVote: {}
    } );
    setLoading( false );
    setError( null );
    setPendingMetrics( {} );
    setHasLoaded( false );
  }, [referenceId, summaryId, speciesUuid] );

  if ( !hasReferenceMetrics || !referenceId ) {
    if ( !children ) {
      return null;
    }
    return (
      <div className="fg-reference-link-row">
        <div className="fg-reference-link-column">
          {children}
        </div>
      </div>
    );
  }

  const panelId = referenceId && summaryId
    ? `reference-feedback-panel-${summaryId}-${referenceId}`
    : undefined;

  const canLoad = Boolean( referenceId && summaryId && speciesUuid );

  const canVote = Boolean( canLoad && hasLoaded && currentUserId );

  const feedbackOptions = referenceMetricKeys.map( metric => ( {
    key: metric,
    label: referenceMetricLabel( metric, { speciesLabel } ),
    up: metricsState?.counts?.[metric]?.up || 0,
    down: metricsState?.counts?.[metric]?.down || 0
  } ) );

  const feedbackMessage = useMemo( ( ) => {
    if ( !currentUserId ) {
      return I18n.t( "id_summaries.demo.reference_feedback.sign_in_required" );
    }
    if ( !canLoad ) {
      return I18n.t( "id_summaries.demo.reference_feedback.unavailable" );
    }
    return null;
  }, [currentUserId, canLoad] );

  const disableTooltip = !canLoad
    ? I18n.t( "id_summaries.demo.reference_feedback.unavailable" )
    : undefined;

  const loadMetrics = useCallback( async () => {
    if ( !canLoad || loading || hasLoaded ) { return; }
    setLoading( true );
    const latest = await fetchReferenceMetricsCounts( {
      taxonSummaryUuid: speciesUuid,
      summaryId,
      referenceId,
      options: { useAuth: true }
    } ) || {
      counts: buildEmptyReferenceMetricCounts(),
      userVote: {}
    };
    setMetricsState( latest );
    setHasLoaded( true );
    setLoading( false );
  }, [
    canLoad,
    loading,
    hasLoaded,
    speciesUuid,
    summaryId,
    referenceId
  ] );

  const handleToggle = () => {
    if ( !canLoad ) {
      setError( I18n.t( "id_summaries.demo.reference_feedback.unavailable" ) );
      return;
    }
    if ( isOpen ) { return; }
    setIsOpen( true );
    setError( null );
    loadMetrics();
  };

  const updatePending = ( metricKey, value ) => {
    setPendingMetrics( prev => {
      const next = { ...prev };
      if ( value ) {
        next[metricKey] = true;
      } else {
        delete next[metricKey];
      }
      return next;
    } );
  };

  const handleVote = async ( metricKey, voteValue ) => {
    if ( !canVote || !canLoad ) {
      setError( I18n.t( "id_summaries.demo.reference_feedback.sign_in_required" ) );
      return;
    }
    const api = inatjs?.taxon_id_summaries;
    if (
      !api
      || typeof api.setReferenceQualityMetric !== "function"
      || typeof api.deleteReferenceQualityMetric !== "function"
    ) {
      setError( I18n.t( "id_summaries.demo.reference_feedback.service_unavailable" ) );
      return;
    }
    const currentVote = metricsState?.userVote?.[metricKey] || 0;
    const nextVote = currentVote === voteValue ? 0 : voteValue;
    updatePending( metricKey, true );
    try {
      if ( nextVote === 0 ) {
        await api.deleteReferenceQualityMetric(
          {
            uuid: speciesUuid,
            id: summaryId,
            reference_id: referenceId,
            metric: metricKey
          },
          { useAuth: true }
        );
      } else {
        await api.setReferenceQualityMetric(
          {
            uuid: speciesUuid,
            id: summaryId,
            reference_id: referenceId,
            metric: metricKey,
            agree: nextVote === 1
          },
          { useAuth: true }
        );
      }
      setMetricsState( prev => {
        const prevCounts = { ...( prev?.counts || buildEmptyReferenceMetricCounts() ) };
        const metricCounts = { ...( prevCounts[metricKey] || { up: 0, down: 0 } ) };
        if ( currentVote === 1 ) {
          metricCounts.up = Math.max( 0, metricCounts.up - 1 );
        } else if ( currentVote === -1 ) {
          metricCounts.down = Math.max( 0, metricCounts.down - 1 );
        }
        if ( nextVote === 1 ) {
          metricCounts.up += 1;
        } else if ( nextVote === -1 ) {
          metricCounts.down += 1;
        }
        const userVote = { ...( prev?.userVote || {} ) };
        if ( nextVote === 0 ) {
          delete userVote[metricKey];
        } else {
          userVote[metricKey] = nextVote;
        }
        prevCounts[metricKey] = metricCounts;
        return {
          counts: prevCounts,
          userVote
        };
      } );
      setError( null );
    } catch ( err ) {
      // eslint-disable-next-line no-console
      console.error( "Failed to submit reference feedback", err );
      setError(
        err?.message
        || I18n.t( "id_summaries.demo.reference_feedback.submit_failed" )
      );
      try {
        const latest = await fetchReferenceMetricsCounts( {
          taxonSummaryUuid: speciesUuid,
          summaryId,
          referenceId,
          options: { useAuth: true }
        } ) || {
          counts: buildEmptyReferenceMetricCounts(),
          userVote: {}
        };
        setMetricsState( latest );
      } catch ( refreshError ) {
        // eslint-disable-next-line no-console
        console.warn( "Unable to refresh reference feedback", refreshError );
      }
    } finally {
      updatePending( metricKey, false );
    }
  };

  const renderFeedbackList = () => (
    <ul className="fg-feedback-options">
      {feedbackOptions.map( option => {
        const voteState = metricsState?.userVote?.[option.key] || 0;
        const pending = !!pendingMetrics?.[option.key];
        let disableReason;
        if ( !canVote ) {
          disableReason = I18n.t( "id_summaries.demo.reference_feedback.sign_in_tooltip" );
        } else if ( pending ) {
          disableReason = I18n.t( "id_summaries.demo.reference_feedback.submitting_tooltip" );
        }
        const canSubmit = canVote && !pending;
        return (
          <li key={option.key} className="fg-feedback-option">
            <span className="fg-feedback-option-label">{option.label}</span>
            <span className="fg-feedback-option-votes">
              <button
                type="button"
                className={`fg-feedback-thumb up${voteState === 1 ? " active" : ""}${pending ? " pending" : ""}`}
                onClick={() => ( canSubmit ? handleVote( option.key, 1 ) : null )}
                disabled={!canSubmit}
                aria-pressed={voteState === 1}
                aria-label={I18n.t( "id_summaries.demo.reference_feedback.aria_helpful", {
                  label: option.label
                } )}
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
                onClick={() => ( canSubmit ? handleVote( option.key, -1 ) : null )}
                disabled={!canSubmit}
                aria-pressed={voteState === -1}
                aria-label={I18n.t( "id_summaries.demo.reference_feedback.aria_not_helpful", {
                  label: option.label
                } )}
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
  );

  const renderFeedbackPanel = () => (
    <div
      id={panelId}
      className="fg-reference-feedback-panel"
      role="region"
      aria-live="polite"
    >
      {loading ? (
        <div className="fg-reference-feedback-status">
          {I18n.t( "id_summaries.demo.reference_feedback.loading" )}
        </div>
      ) : null}
      {error ? (
        <div className="fg-error-flash fg-reference-feedback-error" role="alert">
          {error}
        </div>
      ) : null}
      {feedbackMessage ? (
        <div className="fg-reference-feedback-note">{feedbackMessage}</div>
      ) : null}
      {renderFeedbackList()}
    </div>
  );

  return (
    <div className={`fg-reference-link-row${isOpen ? " is-open" : ""}`}>
      <div className="fg-reference-feedback-column">
        {!isOpen ? (
          <button
            type="button"
            className="fg-reference-feedback-toggle"
            onClick={handleToggle}
            aria-expanded={false}
            aria-controls={panelId}
            disabled={!canLoad}
            title={disableTooltip}
          >
            <span className="fg-reference-feedback-toggle-text">
              {I18n.t( "id_summaries.demo.summary_item.view_reference_feedback" )}
            </span>
            <span className="fg-reference-feedback-toggle-icon" aria-hidden="true">
              <svg width="14" height="14" viewBox="0 0 24 24">
                <path
                  d="M6 9l6 6 6-6"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </span>
          </button>
        ) : null}
        {isOpen ? renderFeedbackPanel() : null}
      </div>
      {children ? (
        <div className="fg-reference-link-column">
          {children}
        </div>
      ) : null}
    </div>
  );
};

ReferenceFeedback.propTypes = {
  reference: PropTypes.shape( {
    id: PropTypes.oneOfType( [PropTypes.number, PropTypes.string] )
  } ).isRequired,
  summaryId: PropTypes.oneOfType( [PropTypes.number, PropTypes.string] ),
  speciesUuid: PropTypes.string,
  speciesLabel: PropTypes.string,
  children: PropTypes.node
};

ReferenceFeedback.defaultProps = {
  summaryId: null,
  speciesUuid: null,
  speciesLabel: null,
  children: null
};

export default ReferenceFeedback;
