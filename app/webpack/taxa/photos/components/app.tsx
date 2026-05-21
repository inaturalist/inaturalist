import React from "react";
import { renderToString } from "react-dom/server";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonCrumbsContainer from "../containers/taxon_crumbs_container";
import PlaceChooserContainer from "../containers/place_chooser_container";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import PhotoBrowserContainer from "../containers/photo_browser_container";
import PhotoModalContainer from "../containers/photo_modal_container";
import { urlForTaxon } from "../../shared/util";
import type { Taxon, Config } from "../../../shared/types";

interface Props {
  taxon: Taxon;
  config?: Config;
}

const App = ( { taxon, config = {} }: Props ) => {
  const taxonHTML = renderToString(
    <SplitTaxon
      taxon={taxon}
      user={config.currentUser}
    />
  );
  return (
    <div id="Photos">
      <div className="taxon-detail-inner">
        <div className="preheader">
          <div className="preheader-search">
            <TaxonAutocomplete
              inputClassName="input-sm"
              bootstrapClear
              placeholder={I18n.t( "search_species_" )}
              searchExternal={false}
              afterSelect={( result: { item: unknown } ) => {
                const url = urlForTaxon( result.item );
                if ( url ) { window.location.href = url; }
              }}
              position={{ my: "right top", at: "right bottom", collision: "none" }}
              config={config}
            />
          </div>
          <div className="preheader-crumbs">
            <TaxonCrumbsContainer />
            <a
              className="permalink"
              href={`/taxa/${taxon.id}-${taxon.name.replace( /[^a-zA-Z0-9]/g, "-" )}`}
              aria-label={I18n.t( "permalink" )}
            >
              <i className="icon-link" />
            </a>
          </div>
        </div>
        <div id="TaxonHeader">
          <div className="inner">
            <div id="place-chooser-container">
              <PlaceChooserContainer container={$( "#app" ).get( 0 )} clearButton />
            </div>
            <h1
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={
                { __html: I18n.t( "photos_of_taxon_html", { taxon: taxonHTML } ) }
              }
            />
          </div>
        </div>
      </div>
      <PhotoBrowserContainer />
      <PhotoModalContainer />
    </div>
  );
};

export default App;
