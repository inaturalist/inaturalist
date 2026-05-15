import React from "react";
import ReactDOMServer from "react-dom/server";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import SplitTaxon from "../../../shared/components/split_taxon";
import ErrorBoundary from "../../../shared/components/error_boundary";
import { urlForTaxon, taxonLayerForTaxon } from "../../shared/util";

interface Bounds {
  swlng: number;
  swlat: number;
  nelng: number;
  nelat: number;
}

interface Taxon {
  id: number;
  name: string;
  preferred_common_name?: string;
  [key: string]: unknown;
}

interface Props {
  taxon?: Taxon;
  bounds?: Bounds;
  latitude?: number;
  longitude?: number;
  zoomLevel?: number;
  config?: { currentUser?: unknown; [key: string]: unknown };
  updateCurrentUser?: ( updates: unknown ) => void;
}

const TaxonPageMap = ( {
  taxon,
  bounds,
  latitude,
  longitude,
  zoomLevel,
  config = {},
  updateCurrentUser
}: Props ) => {
  let loading: React.ReactNode;
  let taxonMap: React.ReactNode;
  if ( taxon ) {
    const t: Taxon & { forced_name?: string; common_name?: { name: string } } = Object.assign(
      { },
      taxon,
      {
        forced_name: ReactDOMServer.renderToString(
          <SplitTaxon
            taxon={taxon}
            user={config.currentUser}
            noParens
            iconLink
            url={urlForTaxon( taxon )}
          />
        )
      }
    );
    if ( t.preferred_common_name ) {
      t.common_name = { name: t.preferred_common_name };
    }
    taxonMap = (
      <ErrorBoundary key="taxa-show-map">
        <TaxonMap
          placement="taxa-show"
          showAllLayer={false}
          minZoom={2}
          gbifLayerLabel={I18n.t( "maps.overlays.gbif_network" )}
          taxonLayers={[
            taxonLayerForTaxon( taxon, { currentUser: config.currentUser, updateCurrentUser } )
          ]}
          minX={bounds ? bounds.swlng : null}
          minY={bounds ? bounds.swlat : null}
          maxX={bounds ? bounds.nelng : null}
          maxY={bounds ? bounds.nelat : null}
          latitude={latitude}
          longitude={longitude}
          zoomLevel={zoomLevel}
          gestureHandling="auto"
          currentUser={config.currentUser}
          updateCurrentUser={updateCurrentUser}
          reloadKey={`taxa-show-map-${taxon.id}${bounds ? "-bounds" : ""}`}
          showLegend
        />
      </ErrorBoundary>
    );
  } else {
    loading = <span className="loading status">{ I18n.t( "loading" ) }</span>;
  }
  return (
    <div className="TaxonPageMap">
      { loading }
      { taxonMap }
    </div>
  );
};

export default TaxonPageMap;
