/* global I18n */

import React, { useEffect, useMemo, useState } from "react";
import PropTypes from "prop-types";
import orderBy from "lodash/orderBy";
import inatjs from "inaturalistjs";
import SummaryItem from "./SummaryItem";
import SummaryFeedback from "./SummaryFeedback";
import {
  publicMetricKeys,
  hasPublicMetrics,
  metricLabel,
  buildEmptyMetricCounts,
  fetchSummaryMetricsCounts
} from "../util/metrics";

const ChevronIcon = ( { isOpen } ) => (
  <svg
    width="14"
    height="14"
    viewBox="0 0 24 24"
    aria-hidden="true"
    className={isOpen ? "is-open" : ""}
  >
    <path
      d="M6 9l6 6 6-6"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const SummaryList = ( {
  speciesId,
  speciesUuid,
  summaries = [],
  isLoading,
  tipVotes = {},
  onVote,
  referenceUsers = {}
} ) => {
  const [feedbackOpen, setFeedbackOpen] = useState( false );
  const [metricsBySummary, setMetricsBySummary] = useState( {} );
  const [metricsLoading, setMetricsLoading] = useState( false );
  const [pendingVotes, setPendingVotes] = useState( {} );
  const [voteError, setVoteError] = useState( null );

  useEffect( () => {
    setFeedbackOpen( false );
    setMetricsBySummary( {} );
    setMetricsLoading( false );
    setPendingVotes( {} );
    setVoteError( null );
  }, [speciesId] );

  const sortedSummaries = useMemo(
    ( ) => orderBy(
      summaries,
      [tip => ( Number.isFinite( tip?.score ) ? tip.score : -Infinity )],
      ["desc"]
    ),
    [summaries]
  );

  const summariesMissingMetrics = useMemo( ( ) => {
    if ( !hasPublicMetrics ) { return []; }
    return sortedSummaries.filter( summary => (
      summary?.id && !metricsBySummary[summary.id]
    ) );
  }, [sortedSummaries, metricsBySummary] );

  useEffect( ( ) => {
    let cancelled = false;
    if (
      !feedbackOpen
      || !hasPublicMetrics
      || !speciesUuid
      || summariesMissingMetrics.length === 0
    ) {
      return undefined;
    }
    setMetricsLoading( true );
    Promise.all(
      summariesMissingMetrics.map( async summary => {
        const data = await fetchSummaryMetricsCounts( {
          taxonSummaryUuid: speciesUuid,
          summaryId: summary.id,
          options: { useAuth: true }
        } );
        return { id: summary.id, data };
      } )
    )
      .then( results => {
        if ( cancelled ) { return; }
        setMetricsBySummary( prev => {
          const merged = { ...prev };
          results.forEach( ( { id, data } ) => {
            merged[id] = data;
          } );
          return merged;
        } );
      } )
      .finally( () => {
        if ( !cancelled ) {
          setMetricsLoading( false );
        }
      } );
    return ( ) => {
      cancelled = true;
    };
  }, [
    feedbackOpen,
    speciesUuid,
    summariesMissingMetrics
  ] );

  useEffect( ( ) => {
    if ( !feedbackOpen ) {
      setVoteError( null );
      setMetricsLoading( false );
    }
  }, [feedbackOpen] );

  const currentUserId = useMemo( ( ) => (
    typeof window !== "undefined"
    && window.CURRENT_USER
    && window.CURRENT_USER.id
  ) || null, [] );

  const updatePending = ( summaryId, metric, value ) => {
    setPendingVotes( prev => {
      const next = { ...prev };
      const summaryPending = { ...( next[summaryId] || {} ) };
      if ( value ) {
        summaryPending[metric] = true;
        next[summaryId] = summaryPending;
      } else {
        delete summaryPending[metric];
        if ( Object.keys( summaryPending ).length > 0 ) {
          next[summaryId] = summaryPending;
        } else {
          delete next[summaryId];
        }
      }
      return next;
    } );
  };

  const handleMetricVote = async ( summary, metricKey, voteValue ) => {
    if ( !hasPublicMetrics ) { return; }
    const summaryId = summary?.id;
    if ( !speciesUuid || !summaryId ) {
      setVoteError( I18n.t( "id_summaries.demo.summary_list.feedback_unavailable" ) );
      return;
    }
    if ( !currentUserId ) {
      setVoteError( I18n.t( "id_summaries.demo.summary_list.sign_in_required" ) );
      return;
    }

    const api = inatjs?.taxon_id_summaries;
    if ( !api
      || typeof api.setSummaryQualityMetric !== "function"
      || typeof api.deleteSummaryQualityMetric !== "function" ) {
      setVoteError( I18n.t( "id_summaries.demo.summary_list.service_unavailable" ) );
      return;
    }

    const summaryState = metricsBySummary[summaryId] || {
      counts: buildEmptyMetricCounts(),
      userVote: {}
    };
    const currentVote = summaryState.userVote?.[metricKey] || 0;
    const nextVote = currentVote === voteValue ? 0 : voteValue;

    updatePending( summaryId, metricKey, true );
    try {
      if ( nextVote === 0 ) {
        await api.deleteSummaryQualityMetric(
          { uuid: speciesUuid, id: summaryId, metric: metricKey },
          { useAuth: true }
        );
      } else {
        await api.setSummaryQualityMetric(
          {
            uuid: speciesUuid,
            id: summaryId,
            metric: metricKey,
            agree: nextVote === 1
          },
          { useAuth: true }
        );
      }

      setMetricsBySummary( prev => {
        const prevState = prev[summaryId] || {
          counts: buildEmptyMetricCounts(),
          userVote: {}
        };
        const counts = { ...prevState.counts };
        const metricCounts = { ...( counts[metricKey] || { up: 0, down: 0 } ) };
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
        counts[metricKey] = metricCounts;
        const userVote = { ...prevState.userVote };
        if ( nextVote === 0 ) {
          delete userVote[metricKey];
        } else {
          userVote[metricKey] = nextVote;
        }
        return {
          ...prev,
          [summaryId]: {
            counts,
            userVote
          }
        };
      } );
      setVoteError( null );
    } catch ( error ) {
      // eslint-disable-next-line no-console
      console.error( "Failed to submit summary feedback", error );
      setVoteError(
        error?.message
        || I18n.t( "id_summaries.demo.summary_list.submit_failed" )
      );
      try {
        const latest = await fetchSummaryMetricsCounts( {
          taxonSummaryUuid: speciesUuid,
          summaryId,
          options: { useAuth: true }
        } );
        setMetricsBySummary( prev => ( {
          ...prev,
          [summaryId]: latest
        } ) );
      } catch ( refreshError ) {
        // eslint-disable-next-line no-console
        console.warn( "Unable to refresh feedback counts", refreshError );
      }
    } finally {
      updatePending( summaryId, metricKey, false );
    }
  };

  if ( isLoading && sortedSummaries.length === 0 ) {
    return (
      <div className="fg-subtle">
        {I18n.t( "id_summaries.demo.summary_list.loading" )}
      </div>
    );
  }

  const hasFeedback = hasPublicMetrics;

  if ( sortedSummaries.length === 0 ) {
    return (
      <div className="fg-summary-empty">
        <p className="fg-muted">
          {I18n.t( "id_summaries.demo.summary_list.empty" )}
        </p>
      </div>
    );
  }

  return (
    <>
      {isLoading ? (
        <div className="fg-subtle" style={{ marginBottom: 12 }}>
          {I18n.t( "id_summaries.demo.summary_list.refreshing" )}
        </div>
      ) : null}
      <div className="fg-summary-header-grid">
        <h2 className="fg-detail-subheading">
          {I18n.t( "id_summaries.demo.summary_list.heading" )}
        </h2>
        <div className="fg-feedback-header-panel">
          {hasFeedback ? (
            <button
              type="button"
              className="fg-feedback-toggle-button"
              onClick={() => setFeedbackOpen( prev => !prev )}
              aria-expanded={feedbackOpen}
            >
              <span className="fg-feedback-toggle-label">
                {I18n.t( "id_summaries.demo.summary_list.feedback_toggle" )}
              </span>
              <span aria-hidden="true" className="fg-feedback-toggle-button-icon">
                <ChevronIcon isOpen={feedbackOpen} />
              </span>
            </button>
          ) : null}
        </div>
      </div>
      {voteError ? (
        <div className="fg-error-flash" role="alert">{voteError}</div>
      ) : null}
      <div className="fg-summary-list">
        {sortedSummaries.map( ( summary, index ) => {
          const baseCounts = buildEmptyMetricCounts();
          const metricsReady = !!( summary?.id && metricsBySummary[summary.id] );
          const summaryState = metricsReady
            ? metricsBySummary[summary.id]
            : { counts: baseCounts, userVote: {} };
          const summaryCounts = summaryState.counts || baseCounts;
          const summaryUserVotes = summaryState.userVote || {};
          const feedbackOptions = publicMetricKeys.map( metric => ( {
            key: metric,
            label: metricLabel( metric ),
            up: summaryCounts?.[metric]?.up || 0,
            down: summaryCounts?.[metric]?.down || 0
          } ) );
          const summaryPending = pendingVotes[summary?.id] || {};
          const canVoteOnSummary = !!( currentUserId && summary?.id && speciesUuid && metricsReady );
          const feedbackMessage = !currentUserId
            ? I18n.t( "id_summaries.demo.summary_list.sign_in_required" )
            : ( !summary?.id || !speciesUuid )
              ? I18n.t( "id_summaries.demo.summary_list.feedback_unavailable" )
              : null;
          const summaryKey = `${speciesId || "species"}-summary-${index}`;
          return (
            <React.Fragment key={summaryKey}>
              <div className="fg-summary-entry">
                <SummaryItem
                  speciesId={speciesId}
                  summary={summary}
                  index={index}
                  currentVote={tipVotes?.[index] || 0}
                  onVote={onVote}
                  referenceUsers={referenceUsers}
                />
              </div>
              <div className="fg-feedback-entry">
                {hasFeedback && feedbackOpen ? (
                  <SummaryFeedback
                    options={feedbackOptions}
                    userVote={summaryUserVotes}
                    onVote={( metric, value ) => handleMetricVote( summary, metric, value )}
                    canVote={canVoteOnSummary}
                    pendingMetrics={summaryPending}
                    loading={metricsLoading && summariesMissingMetrics.length > 0}
                    message={feedbackMessage}
                    showExplainer={index === 0}
                  />
                ) : null}
              </div>
            </React.Fragment>
          );
        } )}
      </div>
    </>
  );
};

export default SummaryList;

const summaryShape = PropTypes.shape( {
  id: PropTypes.oneOfType( [PropTypes.number, PropTypes.string] ),
  text: PropTypes.string,
  photoTip: PropTypes.string,
  group: PropTypes.string,
  score: PropTypes.number,
  sources: PropTypes.arrayOf( PropTypes.shape( {
    url: PropTypes.string,
    comment_uuid: PropTypes.string,
    user_id: PropTypes.number,
    body: PropTypes.string,
    reference_uuid: PropTypes.string,
    reference_source: PropTypes.string,
    created_at: PropTypes.oneOfType( [PropTypes.string, PropTypes.instanceOf( Date )] )
  } ) )
} );

SummaryList.propTypes = {
  speciesId: PropTypes.oneOfType( [PropTypes.number, PropTypes.string] ),
  speciesUuid: PropTypes.string,
  summaries: PropTypes.arrayOf( summaryShape ),
  isLoading: PropTypes.bool,
  tipVotes: PropTypes.objectOf( PropTypes.number ),
  onVote: PropTypes.func,
  referenceUsers: PropTypes.objectOf( PropTypes.shape( {
    id: PropTypes.number,
    login: PropTypes.string,
    name: PropTypes.string,
    icon: PropTypes.string
  } ) )
};
