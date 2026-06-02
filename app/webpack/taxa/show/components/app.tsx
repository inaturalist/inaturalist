import React from "react";
import ErrorBoundary from "../../../shared/components/error_boundary";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPageHeader from "../../shared/components/taxon_page_header";
import PhotoPreviewContainer from "../containers/photo_preview_container";
import ChartsContainer from "../containers/charts_container";
import Leaders from "./leaders";
import TaxonPageTabsContainer from "../containers/taxon_page_tabs_container";
import PhotoModalContainer from "../containers/photo_modal_container";
import PhotoChooserModalContainer from "../containers/photo_chooser_modal_container";
import PlaceChooserContainer from "../containers/place_chooser_container";
import TaxonChangeAlertContainer from "../containers/taxon_change_alert_container";

import AkaNamesContainer from "../containers/aka_names_container";
import StatusRow from "./status_row";
import RtlTestGroupToggle from "../../../shared/components/rtl_test_group_toggle";
import type { Taxon as BaseTaxon, Config } from "../../../shared/types";
import { isCuratorOrAdmin } from "../../shared/util";

type Taxon = BaseTaxon & {
  conservationStatus?: object | null;
  establishment_means?: object | null;
};

interface Props {
  taxon: Taxon;
  showNewTaxon: ( taxon: unknown ) => void;
  config?: Config;
}

const App = ( { taxon, showNewTaxon, config = {} }: Props ) => {
  const flagsButton = isCuratorOrAdmin( config.currentUser )
    && taxon.flag_counts
    && Number( taxon.flag_counts.unresolved ) > 0
    ? (
      <a href={`/taxa/${taxon.id}/flags`} className="btn btn-default btn-flags">
        <i className="fa fa-flag" />
        { " " }
        { I18n.t( "flags_with_count", { count: taxon.flag_counts.unresolved } ) }
      </a>
    )
    : null;
  return (
    <div id="TaxonDetail">
      <TaxonPageHeader
        taxon={taxon}
        config={config}
        heading={(
          <h1>
            <SplitTaxon taxon={taxon} user={config.currentUser} />
            { flagsButton }
          </h1>
      )}
        afterSelect={( result: { item: unknown } ) => showNewTaxon( result.item )}
        showNewTaxon={showNewTaxon}
        placeChooser={<PlaceChooserContainer container={$( "#app" ).get( 0 )} clearButton />}
        prefix={<TaxonChangeAlertContainer />}
        extra={<AkaNamesContainer />}
      />
      <div id="hero">
        <StatusRow
          conservationStatus={taxon.conservationStatus}
          establishmentMeans={taxon.establishment_means}
        />
        <div className="hero-grid">
          <PhotoPreviewContainer />
          <div className="hero-right">
            <Leaders taxon={taxon} />
            <ErrorBoundary>
              <ChartsContainer />
            </ErrorBoundary>
          </div>
        </div>
      </div>
      <TaxonPageTabsContainer />
      <PhotoModalContainer />
      <PhotoChooserModalContainer />
      <RtlTestGroupToggle config={config} />
    </div>
  );
};

export default App;
