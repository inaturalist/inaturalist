/* global I18n */

import React, { useMemo, useState } from "react";
import PropTypes from "prop-types";

const SummaryItem = ( { summary, referenceUsers } ) => {
  const [showReferences, setShowReferences] = useState( false );

  const references = useMemo(
    () => ( Array.isArray( summary?.sources )
      ? summary.sources.filter( source => source?.body || source?.url )
      : [] ),
    [summary]
  );

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

  const toggleReferences = () => {
    if ( references.length === 0 ) return;
    setShowReferences( prev => !prev );
  };

  const disclaimer = I18n.t( "id_summaries.demo.summary_item.disclaimer" );

  const formatReferenceTimestamp = createdAt => {
    if ( !createdAt ) return null;
    const date = new Date( createdAt );
    if ( Number.isNaN( date.getTime() ) ) return null;
    const now = new Date();
    const diffYears = ( now.getTime() - date.getTime() ) / ( 1000 * 60 * 60 * 24 * 365 );
    if ( diffYears >= 1.5 ) {
      return `${Math.round( diffYears )}y`;
    }
    return date.toLocaleDateString( undefined, { month: "short", year: "2-digit" } );
  };

  const renderUserAvatar = ( user, fallbackText ) => {
    if ( user?.icon ) {
      return <img src={user.icon} alt={fallbackText} />;
    }
    return <span className="fg-reference-avatar-placeholder" aria-hidden="true" />;
  };

  const getUser = userId => referenceUsers?.[userId] || null;
  const buildReferenceLink = ref => {
    if ( !ref ) return null;
    if ( ref?.reference_source === "identification" && ref?.reference_uuid ) {
      return `/identifications/${ref.reference_uuid}`;
    }
    if ( ref?.reference_source === "observation" && ref?.reference_uuid ) {
      return `/comments/${ref.reference_uuid}`;
    }
    if ( ref?.url ) return ref.url;
    return null;
  };
  const formatReferenceBody = body => {
    if ( !body ) return "";
    const looksLikeHtml = /<\s*[a-z][^>]*>/i.test( body );
    if ( looksLikeHtml ) return body;
    return body.replace( /\n/g, "<br />" );
  };

  const fallbackLabel = I18n.t( "id_summaries.demo.summary_item.default_label" );
  const labelText = summary?.group ? summary.group.toUpperCase() : fallbackLabel;
  const labelTitle = summary?.group
    ? summary.group
    : I18n.t( "id_summaries.demo.summary_item.default_title" );

  return (
    <div className="fg-summary-card">
      <div className="fg-summary-header">
        <span className="fg-summary-label" title={labelTitle}>
          <span className="fg-summary-label-icon" aria-hidden="true" />
          <span>{labelText}</span>
        </span>
      </div>

      <p className="fg-summary-text">{summary?.text}</p>
      <p className="fg-summary-disclaimer">{disclaimer}</p>

      {references.length ? (
        <div className={`fg-summary-references${showReferences ? " is-open" : ""}`}>
          <button
            type="button"
            className="fg-summary-references-toggle"
            onClick={toggleReferences}
            aria-expanded={showReferences}
          >
            <span className="fg-summary-references-icon">
              <ChevronIcon isOpen={showReferences} />
            </span>
            <span>{I18n.t( "id_summaries.demo.summary_item.references_toggle" )}</span>
          </button>

          {showReferences ? (
            <ul className="fg-reference-list">
              {references.map( ( ref, referenceIndex ) => {
                const user = getUser( ref?.user_id );
                const displayName = user?.login
                  || user?.name
                  || I18n.t( "id_summaries.demo.summary_item.user_fallback" );
                const timestamp = formatReferenceTimestamp( ref?.created_at );
                const link = buildReferenceLink( ref );
                const avatarLabel = user?.login
                  || user?.name
                  || I18n.t( "id_summaries.demo.summary_item.user_fallback" );
                return (
                  <li
                    key={`${ref?.comment_uuid || ref?.url || referenceIndex}`}
                    className="fg-reference-item"
                  >
                    <div className="fg-reference-avatar">
                      {renderUserAvatar( user, avatarLabel )}
                    </div>
                    <div className="fg-reference-content">
                      <div className="fg-reference-card">
                        <div className="fg-reference-card-header">
                          <div className="fg-reference-card-title">
                            <span className="fg-reference-username">{displayName}</span>
                            <span className="fg-reference-verb">
                              {I18n.t( "id_summaries.demo.summary_item.reference_commented" )}
                            </span>
                          </div>
                          <div className="fg-reference-card-meta">
                            {timestamp ? (
                              <span className="fg-reference-timestamp">{timestamp}</span>
                            ) : null}
                            <span className="fg-reference-card-chevron" aria-hidden="true">
                              <svg width="12" height="12" viewBox="0 0 24 24">
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
                          </div>
                        </div>
                        {ref?.body ? (
                          <div
                            className="fg-reference-body"
                            dangerouslySetInnerHTML={{ __html: formatReferenceBody( ref.body ) }}
                          />
                        ) : null}
                      </div>
                      {link ? (
                        <div className="fg-reference-link-row">
                          <a
                            href={link}
                            className="fg-reference-link"
                            target="_blank"
                            rel="noopener noreferrer"
                          >
                            {I18n.t( "id_summaries.demo.summary_item.view_comment" )}
                          </a>
                        </div>
                      ) : null}
                    </div>
                  </li>
                );
              } )}
            </ul>
          ) : null}
        </div>
      ) : null}
    </div>
  );
};

export default SummaryItem;

SummaryItem.propTypes = {
  summary: PropTypes.shape( {
    id: PropTypes.oneOfType( [PropTypes.number, PropTypes.string] ),
    group: PropTypes.string,
    text: PropTypes.string,
    sources: PropTypes.arrayOf( PropTypes.shape( {
      url: PropTypes.string,
      comment_uuid: PropTypes.string,
      user_id: PropTypes.number,
      body: PropTypes.string,
      reference_uuid: PropTypes.string,
      reference_source: PropTypes.string,
      created_at: PropTypes.oneOfType( [PropTypes.string, PropTypes.instanceOf( Date )] )
    } ) )
  } ),
  referenceUsers: PropTypes.objectOf( PropTypes.shape( {
    id: PropTypes.number,
    login: PropTypes.string,
    name: PropTypes.string,
    icon: PropTypes.string
  } ) )
};
