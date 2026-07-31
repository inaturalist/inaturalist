import React from "react";
import LazyLoad from "react-lazy-load";
import moment from "moment";
import HighlightsCarousel from "./highlights_carousel";
import type { Taxon, Config } from "../../../shared/types";

interface Discovery {
  taxon: Taxon;
  identification: {
    observation: { id: number };
    created_at: string;
    category?: string;
  };
}

interface HighlightsTabProps {
  placeName?: string;
  placeUrl?: string;
  trendingTaxa?: Taxon[] | null;
  wantedTaxa?: Taxon[] | null;
  discoveries?: Discovery[] | null;
  trendingUrl?: string;
  showNewTaxon?: ( taxon: Taxon ) => void;
  discoveriesShown?: boolean;
  wantedShown?: boolean;
  config?: Config;
  fetchRecent?: ( ) => void;
  fetchWanted?: ( ) => void;
}

const HighlightsTab = ( {
  trendingTaxa,
  wantedTaxa,
  discoveries,
  trendingUrl,
  placeName,
  placeUrl,
  showNewTaxon,
  wantedShown,
  discoveriesShown,
  config,
  fetchRecent,
  fetchWanted
}: HighlightsTabProps ) => {
  const discoveryCaptionForTaxon = ( taxon: Taxon ) => {
    const discovery = discoveries && discoveries.find( d => d.taxon.id === taxon.id );
    if ( !discoveries || !discovery ) {
      return <span />;
    }
    return (
      <div className="discovery-caption">
        <a
          href={`/observations/${discovery.identification.observation.id}`}
          className="text-muted"
        >
          { moment( discovery.identification.created_at ).fromNow( ) }
        </a>
      </div>
    );
  };

  const discoveryUrlForTaxon = ( taxon: Taxon ) => {
    const discovery = discoveries && discoveries.find( d => d.taxon.id === taxon.id );
    return discovery
      ? `/observations/${discovery.identification.observation.id}`
      : undefined;
  };

  return (
    <div className="HighlightsTab">
      <HighlightsCarousel
        title={I18n.t( "trending" )}
        url={trendingUrl}
        description={
          placeName
            ? (
              <span
                dangerouslySetInnerHTML={{
                  __html: I18n.t(
                    "views.taxa.show.trending_in_place_desc_html",
                    { place: placeName, url: placeUrl }
                  )
                }}
              />
            )
            : I18n.t( "views.taxa.show.trending_desc" )
        }
        taxa={trendingTaxa ?? undefined}
        showNewTaxon={showNewTaxon}
        config={config}
      />
      { discoveriesShown ? (
        <LazyLoad
          debounce={false}
          minHeight={391}
          offset={100}
          onContentVisible={fetchRecent}
        >
          <HighlightsCarousel
            title={I18n.t( "discoveries" )}
            taxa={discoveries?.map( d => d.taxon )}
            showNewTaxon={showNewTaxon}
            captionForTaxon={discoveryCaptionForTaxon}
            description={I18n.t( "views.taxa.show.discoveries_desc" )}
            urlForTaxon={discoveryUrlForTaxon}
            config={config}
          />
        </LazyLoad>
      ) : null }
      { wantedShown ? (
        <LazyLoad
          debounce={false}
          minHeight={371}
          offset={100}
          onContentVisible={fetchWanted}
        >
          <div className={!wantedTaxa || wantedTaxa.length === 0 ? "hidden" : ""}>
            <HighlightsCarousel
              title={I18n.t( "wanted" )}
              description={I18n.t( "views.taxa.show.wanted_desc" )}
              taxa={wantedTaxa?.slice( 0, 20 )}
              showNewTaxon={showNewTaxon}
              config={config}
            />
          </div>
        </LazyLoad>
      ) : null }
    </div>
  );
};

export default HighlightsTab;
