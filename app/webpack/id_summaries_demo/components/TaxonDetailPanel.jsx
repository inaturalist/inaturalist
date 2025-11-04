/* global I18n */

import React from "react";
import PropTypes from "prop-types";
import SummaryList from "./SummaryList";

const TaxonDetailPanel = ( {
  species,
  imageUrl,
  isSummaryLoading,
  error,
  tipVotes,
  referenceUsers,
  onVote
} ) => {
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

  const runDate = species?.runGeneratedAt ? new Date( species.runGeneratedAt ) : null;
  const formattedRunDate = runDate && !Number.isNaN( runDate.getTime() )
    ? runDate.toLocaleDateString( undefined, {
      month: "numeric",
      day: "numeric",
      year: "2-digit"
    } )
    : null;
  const commonName = species?.commonName || null;
  const scientificName = species?.name || "";

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
          {formattedRunDate ? (
            <div style={lastUpdatedStyle}>
              {I18n.t( "id_summaries.demo.taxon_detail.last_updated" )}
              {" "}
              {formattedRunDate}
            </div>
          ) : null}
        </div>

        {error ? (
          <div style={{ color: "#ef4444", marginBottom: "12px" }}>{error}</div>
        ) : null}

        {imageUrl ? (
          <img src={imageUrl} alt={species.name} className="fg-species-image" />
        ) : (
          <div className="fg-subtle">
            {I18n.t( "id_summaries.demo.taxon_detail.no_image" )}
          </div>
        )}
      </section>

      <section className="fg-main-body">
        <SummaryList
          speciesId={species.id}
          speciesUuid={species.uuid}
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
      } ) )
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
  onVote: PropTypes.func
};

export default TaxonDetailPanel;
