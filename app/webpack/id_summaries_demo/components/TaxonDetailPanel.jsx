/* global I18n */

import React, { useMemo } from "react";
import PropTypes from "prop-types";
import SummaryList from "./SummaryList";
import { LANGUAGE_LABELS } from "../constants/languages";

const formatCommonName = name => {
  if ( !name ) {
    return name;
  }
  const windowObject = typeof window !== "undefined" ? window : null;
  const titleCaseFn = windowObject?.iNatModels?.Taxon?.titleCaseName;
  if ( typeof titleCaseFn === "function" ) {
    return titleCaseFn( name );
  }
  return name;
};

const TaxonDetailPanel = ( {
  species,
  imageUrl,
  isSummaryLoading,
  error,
  tipVotes,
  referenceUsers,
  onVote,
  showPhotoTips,
  photoAttribution,
  adminExtrasVisible
} ) => {
  const speciesIdentifier = species?.id || species?.uuid || null;
  const photoTips = useMemo( () => {
    const tips = [];
    ( species?.tips || [] ).forEach( tip => {
      const rawTip = typeof tip?.photoTip === "string" ? tip.photoTip.trim() : "";
      if ( rawTip && !tips.includes( rawTip ) ) {
        tips.push( rawTip );
      }
    } );
    return tips;
  }, [species] );
  const photoTipsHeading = I18n.t( "id_summaries.demo.taxon_detail.photo_tips_heading" );
  const headerWrapperStyle = {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: "24px",
    marginBottom: "16px"
  };
  const nameBlockStyle = {
    margin: 0, fontSize: "24px", fontWeight: 600, lineHeight: 1.25
  };
  const scientificNameStyle = { fontStyle: "italic", fontWeight: 400 };
  const lastUpdatedStyle = { fontSize: "14px", color: "#111827", whiteSpace: "nowrap" };
  const uuidStyle = { fontSize: "12px", color: "#6b7280", marginTop: "4px", wordBreak: "break-all" };
  const headerMetaStyle = {
    textAlign: "right",
    display: "flex",
    flexDirection: "column",
    alignItems: "flex-end",
    gap: "6px"
  };

  const runDate = species?.runGeneratedAt ? new Date( species.runGeneratedAt ) : null;
  const formattedRunDate = runDate && !Number.isNaN( runDate.getTime() )
    ? runDate.toLocaleDateString( undefined, {
      month: "numeric",
      day: "numeric",
      year: "2-digit"
    } )
    : null;
  const commonName = useMemo(
    () => formatCommonName( species?.commonName ),
    [species?.commonName]
  ) || null;
  const scientificName = species?.name || "";
  const speciesLabel = commonName || scientificName || "";
  const observationLink = species?.taxonPhotoObservationId && species?.taxonPhotoId
    ? `/observations/${species.taxonPhotoObservationId}?photo_id=${species.taxonPhotoId}`
    : null;
  const languageLabel = species?.language
    ? LANGUAGE_LABELS[species.language] || species.language.toUpperCase()
    : null;

  let imageContent = null;
  if ( imageUrl ) {
    const imageElement = (
      <img src={imageUrl} alt={species.name} className="fg-species-image" />
    );
    imageContent = observationLink ? (
      <a
        href={observationLink}
        target="_blank"
        rel="noopener noreferrer"
        className="fg-species-image-link"
        aria-label={
          species?.name
            ? `View observation for ${species.name}`
            : "View observation"
        }
      >
        {imageElement}
      </a>
    ) : imageElement;
  } else {
    imageContent = (
      <div className="fg-species-image-placeholder fg-subtle">
        {I18n.t( "id_summaries.demo.taxon_detail.no_image" )}
      </div>
    );
  }

  if ( !species ) {
    return (
      <div className="fg-muted" style={{ fontSize: "16px" }}>
        {I18n.t( "id_summaries.demo.taxon_detail.select_species" )}
      </div>
    );
  }

  return (
    <div className="fg-main-content">
      <section className="fg-main-top-card">
        <div style={headerWrapperStyle}>
          <h1 style={nameBlockStyle}>
            {commonName ? (
              <>
                {commonName}
                {" "}
                {scientificName ? (
                  <span style={scientificNameStyle}>
                    (
                    {scientificName}
                    )
                  </span>
                ) : null}
              </>
            ) : (
              <span style={scientificNameStyle}>{scientificName}</span>
            )}
          </h1>
          <div style={headerMetaStyle}>
            {formattedRunDate ? (
              <div style={lastUpdatedStyle}>
                {I18n.t( "id_summaries.demo.taxon_detail.last_updated" )}
                {" "}
                {formattedRunDate}
              </div>
            ) : null}
            {languageLabel ? (
              <div className="fg-language-pill">
                {languageLabel}
              </div>
            ) : null}
            {species?.uuid && adminExtrasVisible ? (
              <div style={uuidStyle}>
                <code>{species.uuid}</code>
              </div>
            ) : null}
          </div>
        </div>

        {error ? (
          <div style={{ color: "#ef4444", marginBottom: "12px" }}>{error}</div>
        ) : null}

        <div className="fg-species-hero">
          <div className="fg-species-image-column">
            <div className="fg-species-image-wrapper">
              <div className="fg-species-image-frame">
                {imageContent}
              </div>
              {photoAttribution ? (
                <p className="fg-photo-attribution">{photoAttribution}</p>
              ) : null}
            </div>
          </div>
          {photoTips.length && showPhotoTips ? (
            <aside
              className="fg-photo-tip-panel"
              id={speciesIdentifier ? `photo-tips-${speciesIdentifier}` : undefined}
              aria-label={photoTipsHeading}
            >
              <h2 className="fg-photo-tip-title">{photoTipsHeading}</h2>
              <ol className="fg-photo-tip-list">
                {photoTips.map( ( tip, index ) => (
                  <li key={`photo-tip-${index}`} className="fg-photo-tip-item">
                    <span className="fg-photo-tip-index" aria-hidden="true">
                      {index + 1}
                    </span>
                    <span className="fg-photo-tip-text">{tip}</span>
                  </li>
                ) )}
              </ol>
            </aside>
          ) : null}
        </div>
      </section>

      <section className="fg-main-body">
        <SummaryList
          speciesId={species.id}
          speciesUuid={species.uuid}
          speciesLabel={speciesLabel}
          summaries={species.tips || []}
          isLoading={isSummaryLoading}
          tipVotes={tipVotes}
          referenceUsers={referenceUsers}
          onVote={onVote}
        />
      </section>
    </div>
  );
};

TaxonDetailPanel.propTypes = {
  species: PropTypes.shape( {
    id: PropTypes.number,
    uuid: PropTypes.string,
    name: PropTypes.string,
    commonName: PropTypes.string,
    runGeneratedAt: PropTypes.oneOfType( [PropTypes.string, PropTypes.instanceOf( Date )] ),
    tips: PropTypes.arrayOf( PropTypes.shape( {
      id: PropTypes.oneOfType( [PropTypes.number, PropTypes.string] ),
      text: PropTypes.string,
      score: PropTypes.number,
      sources: PropTypes.arrayOf( PropTypes.shape( {
        url: PropTypes.string,
        comment_uuid: PropTypes.string,
        user_id: PropTypes.number,
        body: PropTypes.string,
        created_at: PropTypes.oneOfType( [PropTypes.string, PropTypes.instanceOf( Date )] )
      } ) ),
      photoTip: PropTypes.string
    } ) )
  } ),
  imageUrl: PropTypes.string,
  isSummaryLoading: PropTypes.bool,
  error: PropTypes.string,
  tipVotes: PropTypes.objectOf( PropTypes.number ),
  referenceUsers: PropTypes.objectOf( PropTypes.shape( {
    id: PropTypes.number,
    login: PropTypes.string,
    name: PropTypes.string,
    icon: PropTypes.string
  } ) ),
  onVote: PropTypes.func,
  showPhotoTips: PropTypes.bool,
  photoAttribution: PropTypes.string,
  adminExtrasVisible: PropTypes.bool
};

export default TaxonDetailPanel;
