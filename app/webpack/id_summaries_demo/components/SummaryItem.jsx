/* global I18n */

import React, { useMemo, useState } from "react";
import PropTypes from "prop-types";
import ReferenceFeedback from "./ReferenceFeedback";

const PhotoTipIcon = () => (
  <svg
    width="16"
    height="16"
    viewBox="0 0 24 24"
    aria-hidden="true"
    focusable="false"
  >
    <path
      d="M9.2 5l1.1-1.8c.2-.3.5-.4.8-.4h2.8c.3 0 .6.2.8.4L15.8 5H19a3 3 0 0 1 3 3v9a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3h4.2zm2.8 4a5 5 0 1 0 0 10 5 5 0 0 0 0-10zm0 2.2a2.8 2.8 0 1 1 0 5.6 2.8 2.8 0 0 1 0-5.6z"
      fill="currentColor"
    />
  </svg>
);

const SummaryItem = ( {
  summary,
  referenceUsers,
  speciesId,
  speciesUuid,
  speciesLabel,
  index
} ) => {
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
  const buildVisualLink = part => {
    if ( !speciesId || !part ) return null;
    const query = encodeURIComponent( part ).replace( /%20/g, "+" );
    return `https://www.inaturalist.org/vision_language_demo?q=${query}&taxon_id=${speciesId}`;
  };
  const renderSummaryText = () => {
    const text = summary?.text;
    if ( !text ) return null;
    const regex = /<visual\s+part=["']([^"']+)["']\s*>([\s\S]*?)<\/visual>/gi;
    const fragments = [];
    let lastIndex = 0;
    let match;
    let keyIndex = 0;
    while ( ( match = regex.exec( text ) ) ) {
      const [wholeMatch, part, content] = match;
      const start = match.index;
      if ( start > lastIndex ) {
        fragments.push(
          <React.Fragment key={`text-${keyIndex}`}>
            {text.substring( lastIndex, start )}
          </React.Fragment>
        );
        keyIndex += 1;
      }
      // Temporarily render the <visual> content without linking to the vision demo.
      fragments.push(
        <React.Fragment key={`visual-text-${keyIndex}`}>
          {content}
        </React.Fragment>
      );
      // const link = buildVisualLink( part );
      // if ( link ) {
      //   fragments.push(
      //     <a
      //       key={`visual-${keyIndex}`}
      //       href={link}
      //       target="_blank"
      //       rel="noopener noreferrer"
      //     >
      //       {content}
      //     </a>
      //   );
      // } else {
      //   fragments.push(
      //     <React.Fragment key={`visual-text-${keyIndex}`}>
      //       {content}
      //     </React.Fragment>
      //   );
      // }
      keyIndex += 1;
      lastIndex = start + wholeMatch.length;
    }
    if ( fragments.length === 0 ) return text;
    if ( lastIndex < text.length ) {
      fragments.push(
        <React.Fragment key={`text-${keyIndex}`}>
          {text.substring( lastIndex )}
        </React.Fragment>
      );
    }
    return fragments;
  };

  const fallbackLabel = I18n.t( "id_summaries.demo.summary_item.default_label" );
  const labelText = summary?.group ? summary.group.toUpperCase() : fallbackLabel;
  const labelTitle = summary?.group
    ? summary.group
    : I18n.t( "id_summaries.demo.summary_item.default_title" );
  const photoTip = typeof summary?.photoTip === "string"
    ? summary.photoTip.trim()
    : "";
  const hasPhotoTip = photoTip.length > 0;
  const photoTipLabel = I18n.t( "id_summaries.demo.summary_item.photo_tip_label" );
  const photoTipAria = I18n.t( "id_summaries.demo.summary_item.photo_tip_aria", {
    tip: photoTip
  } );
  const summaryId = summary?.id;
  const tooltipId = useMemo( () => {
    if ( !hasPhotoTip ) return null;
    const baseId = summaryId || index || 0;
    const safeBase = String( baseId ).replace( /[^a-zA-Z0-9_-]/g, "-" );
    const safeSpecies = speciesId
      ? String( speciesId ).replace( /[^a-zA-Z0-9_-]/g, "-" )
      : "species";
    return `photo-tip-${safeSpecies}-${safeBase}`;
  }, [hasPhotoTip, summaryId, index, speciesId] );

  return (
    <div className="fg-summary-card">
      <div className="fg-summary-header">
        <span className="fg-summary-label" title={labelTitle}>
          <span className="fg-summary-label-icon" aria-hidden="true" />
          <span className="fg-summary-label-text">{labelText}</span>
          {hasPhotoTip ? (
            <span
              className="fg-summary-photo-tip"
              tabIndex="0"
              aria-label={photoTipAria}
              aria-describedby={tooltipId || undefined}
            >
              <span className="fg-summary-photo-tip-icon" aria-hidden="true">
                <PhotoTipIcon />
              </span>
              <span className="fg-summary-photo-tip-text">{photoTipLabel}</span>
              <span
                id={tooltipId || undefined}
                className="fg-summary-photo-tip-tooltip"
                role="tooltip"
              >
                {photoTip}
              </span>
            </span>
          ) : null}
        </span>
      </div>

      <p className="fg-summary-text">{renderSummaryText()}</p>
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
                      <ReferenceFeedback
                        reference={ref}
                        summaryId={summary?.id}
                        speciesUuid={speciesUuid}
                        speciesLabel={speciesLabel}
                      >
                        {link ? (
                          <a
                            href={link}
                            className="fg-reference-link"
                            target="_blank"
                            rel="noopener noreferrer"
                          >
                            {I18n.t( "id_summaries.demo.summary_item.view_comment" )}
                          </a>
                        ) : null}
                      </ReferenceFeedback>
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
    photoTip: PropTypes.string,
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
  } ) ),
  speciesId: PropTypes.oneOfType( [PropTypes.number, PropTypes.string] ),
  speciesUuid: PropTypes.string,
  speciesLabel: PropTypes.string,
  index: PropTypes.number
};
