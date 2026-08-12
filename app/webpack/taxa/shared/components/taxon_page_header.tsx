import React from "react";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import TaxonCrumbsContainer from "../containers/taxon_crumbs_container";
import css from "./taxon_page_header.module.css";
import type { Taxon, Config } from "../../../shared/types";
import { urlForTaxon } from "../util";

interface TaxonPageHeaderProps {
  taxon: Taxon;
  config?: Config;
  heading: React.ReactNode;
  afterSelect: ( result: { item: unknown } ) => void;
  // Each page connects its own place chooser to its own store, so the component
  // is passed in and the header supplies the shared container / props.
  placeChooserContainer?: React.ComponentType<{
    container?: HTMLElement;
    clearButton?: boolean;
  }>;
  showNewTaxon?: ( taxon: unknown ) => void;
  crumbsText?: string;
  prefix?: React.ReactNode;
  suffix?: React.ReactNode;
}

const TaxonPageHeader = ( {
  taxon,
  config = {},
  heading,
  afterSelect,
  placeChooserContainer: PlaceChooserContainer,
  showNewTaxon,
  crumbsText,
  prefix,
  suffix
}: TaxonPageHeaderProps ) => (
  <div className={css["taxon-detail-inner"]}>
    { prefix }
    <div className={css.preheader}>
      <div className={css["preheader-search"]}>
        <TaxonAutocomplete
          inputClassName="input-sm"
          bootstrapClear
          placeholder={I18n.t( "search_species_" )}
          searchExternal={false}
          afterSelect={afterSelect}
          position={{ my: "right top", at: "right bottom", collision: "none" }}
          config={config}
        />
      </div>
      <div className={css["preheader-crumbs"]}>
        <TaxonCrumbsContainer
          showNewTaxon={showNewTaxon}
          currentText={crumbsText}
        />
        <a
          className={css.permalink}
          href={urlForTaxon( taxon ) ?? undefined}
          aria-label={I18n.t( "permalink" )}
        >
          <i className="icon-link" />
        </a>
      </div>
    </div>
    <div id="TaxonHeader" className={css["taxon-header"]}>
      <div className={css.inner}>
        <div id="place-chooser-container">
          { PlaceChooserContainer && (
            <PlaceChooserContainer
              container={document.getElementById( "app" ) ?? undefined}
              clearButton
            />
          ) }
        </div>
        { heading }
      </div>
      { suffix }
    </div>
  </div>
);

export default TaxonPageHeader;
