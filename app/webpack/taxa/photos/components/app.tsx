import React from "react";
import { renderToString } from "react-dom/server";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPageHeader from "../../shared/components/taxon_page_header";

import PlaceChooserContainer from "../containers/place_chooser_container";
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
    <SplitTaxon taxon={taxon} user={config.currentUser} />
  );
  return (
    <div id="Photos">
      <TaxonPageHeader
        taxon={taxon}
        config={config}
        heading={(
          <h1
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={
              { __html: I18n.t( "photos_of_taxon_html", { taxon: taxonHTML } ) }
            }
          />
        )}
        afterSelect={( result: { item: unknown } ) => {
          const url = urlForTaxon( result.item );
          if ( url ) { window.location.href = url; }
        }}
        placeChooser={<PlaceChooserContainer container={$( "#app" ).get( 0 )} clearButton />}
        crumbsText={I18n.t( "photo_browser" )}
      />
      <PhotoBrowserContainer />
      <PhotoModalContainer />
    </div>
  );
};

export default App;
