import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import ErrorBoundary from "../../../shared/components/error_boundary";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import PhotoPreviewContainer from "../containers/photo_preview_container";
import ChartsContainer from "../containers/charts_container";
import Leaders from "./leaders";
import TaxonPageTabsContainer from "../containers/taxon_page_tabs_container";
import PhotoModalContainer from "../containers/photo_modal_container";
import PhotoChooserModalContainer from "../containers/photo_chooser_modal_container";
import PlaceChooserContainer from "../containers/place_chooser_container";
import TaxonChangeAlertContainer from "../containers/taxon_change_alert_container";
import TaxonCrumbsContainer from "../containers/taxon_crumbs_container";
import AkaNamesContainer from "../containers/aka_names_container";
import StatusRow from "./status_row";
import RtlTestGroupToggle from "../../../shared/components/rtl_test_group_toggle";

interface CurrentUser {
  isAdmin?: boolean;
  isInTestGroup?: ( group: string ) => boolean;
  roles?: string[];
  [key: string]: unknown;
}

interface Taxon {
  id: number;
  name: string;
  rank_level?: number;
  complete_species_count?: number;
  conservationStatus?: object | null;
  establishment_means?: object | null;
  flag_counts?: {
    unresolved?: number;
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

interface Props {
  taxon: Taxon;
  showNewTaxon: ( taxon: unknown ) => void;
  config?: { currentUser?: CurrentUser; [key: string]: unknown };
}

const App = ( { taxon, showNewTaxon, config = {} }: Props ) => {
  const responsive = config.currentUser?.isAdmin
    && config.currentUser?.isInTestGroup?.( "responsive-taxon-detail" );
  return (
    <div id="TaxonDetail">
      <Grid>
        <TaxonChangeAlertContainer />
        <Row className="preheader">
          <Col xs={responsive ? undefined : 8} sm={responsive ? 8 : undefined}>
            <TaxonCrumbsContainer />
            <a
              className="permalink"
              href={`/taxa/${taxon.id}-${taxon.name.replace( /[^a-zA-Z0-9]/g, "-" )}`}
              aria-label={I18n.t( "permalink" )}
            >
              <i className="icon-link" />
            </a>
          </Col>
          <Col xs={responsive ? undefined : 4} sm={responsive ? 4 : undefined}>
            <div className="pull-right">
              <TaxonAutocomplete
                inputClassName="input-sm"
                bootstrapClear
                placeholder={I18n.t( "search_species_" )}
                searchExternal={false}
                afterSelect={( result: any ) => showNewTaxon( result.item )}
                position={{ my: "right top", at: "right bottom", collision: "none" }}
                config={config}
              />
            </div>
          </Col>
        </Row>
        <Row id="TaxonHeader">
          <Col xs={12}>
            <div className="inner">
              <h1>
                <SplitTaxon
                  taxon={taxon}
                  user={config.currentUser}
                />
                { config.currentUser
                  && config.currentUser.roles
                  && (
                    config.currentUser.roles.indexOf( "curator" ) >= 0
                    || config.currentUser.roles.indexOf( "admin" ) >= 0
                  )
                  && taxon.flag_counts
                  && taxon.flag_counts.unresolved
                  && taxon.flag_counts.unresolved > 0
                  ? (
                    <a href={`/taxa/${taxon.id}/flags`} className="btn btn-default btn-flags">
                      <i className="fa fa-flag" />
                      { " " }
                      { I18n.t( "flags_with_count", { count: taxon.flag_counts.unresolved } ) }
                    </a>
                  )
                  : null }
              </h1>
              <div id="place-chooser-container">
                <PlaceChooserContainer container={( $ as any )( "#app" ).get( 0 )} clearButton />
              </div>
            </div>
          </Col>
          <Col xs={12}>
            <AkaNamesContainer />
          </Col>
        </Row>
      </Grid>
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
