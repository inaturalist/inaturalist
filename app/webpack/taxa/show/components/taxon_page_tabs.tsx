import React, { useEffect, useRef } from "react";
import {
  Grid,
  Row,
  Col,
  Dropdown,
  MenuItem
} from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import _ from "lodash";
import TaxonPageMapContainer from "../containers/taxon_page_map_container";
import StatusTab from "./status_tab";
import TaxonomyTabContainer from "../containers/taxonomy_tab_container";
import ArticlesTabContainer from "../containers/articles_tab_container";
import InteractionsTabContainer from "../containers/interactions_tab_container";
import HighlightsTabContainer from "../containers/highlights_tab_container";
import SimilarTabContainer from "../containers/similar_tab_container";
import IdentificationsTabContainer from "../containers/identifications_tab_container";
import RecentObservationsContainer from "../containers/recent_observations_container";
import TabDrawer from "../../../shared/components/tab_drawer";

interface Taxon {
  id: number;
  rank_level: number;
  flag_counts?: { resolved: string; unresolved: string };
  photos_locked?: boolean;
  atlas_id?: number;
  conservationStatuses?: unknown;
  listed_taxa_count?: number;
  listed_taxa?: Array<{ establishment_means?: unknown; [key: string]: unknown }>;
  [key: string]: unknown;
}

interface CurrentUser {
  roles: string[];
  canViewHelpfulIDTips: ( ) => boolean;
  privilegedWith: ( perm: string ) => boolean;
  content_creation_restrictions?: boolean;
  [key: string]: unknown;
}

interface Props {
  taxon: Taxon;
  currentUser?: CurrentUser;
  chosenTab?: string;
  loadDataForTab: ( tab: string ) => void;
  choseTab: ( tab: string ) => void;
  showPhotoChooserModal: ( ) => void;
}

const TaxonPageTabs = ( {
  taxon,
  currentUser,
  chosenTab = "articles",
  loadDataForTab,
  choseTab,
  showPhotoChooserModal
}: Props ) => {
  const containerRef = useRef<HTMLDivElement>( null );
  const prevTaxonIdRef = useRef<number | null>( null );
  const prevChosenTabRef = useRef<string>( chosenTab );
  const choseTabRef = useRef( choseTab );
  choseTabRef.current = choseTab;

  useEffect( ( ) => {
    if ( !containerRef.current ) return;
    ( $ as any )( "a[data-toggle=tab]", containerRef.current ).on(
      "shown.bs.tab",
      ( e: any ) => {
        choseTabRef.current( e.target.hash.match( /#(.+)-tab/ )[1] );
      }
    );
  }, [] );

  useEffect( ( ) => {
    const currTaxonId = taxon ? taxon.id : null;
    if ( prevTaxonIdRef.current !== null && prevTaxonIdRef.current !== currTaxonId ) {
      loadDataForTab( chosenTab );
    }
    prevTaxonIdRef.current = currTaxonId;
  }, [taxon?.id] );

  useEffect( ( ) => {
    if ( chosenTab === "map" && prevChosenTabRef.current !== "map" ) {
      const taxonMap = ( $ as any )( ".TaxonMap", containerRef.current );
      // If google wasn't initialized for some reason, doing any of this will
      // crash, and we can't use an ErrorBoundary in a callback like this
      if ( typeof ( window as any ).google !== "undefined" ) {
        ( window as any ).google.maps.event.trigger( taxonMap.data( "taxonMap" ), "resize" );
        taxonMap.taxonMap( taxonMap.data( "taxonMapOptions" ) );
      }
    }
    prevChosenTabRef.current = chosenTab;
  }, [chosenTab] );

  const { test } = ( $ as any ).deparam.querystring( );
  const speciesOrLower = taxon && taxon.rank_level <= 10;
  const genusOrSpecies = taxon && ( taxon.rank_level === 20 || taxon.rank_level === 10 );
  const flagsCount = taxon.flag_counts
    ? parseInt( taxon.flag_counts.resolved, 10 ) + parseInt( taxon.flag_counts.unresolved, 10 )
    : 0;
  const isCurator = currentUser?.roles.indexOf( "curator" ) >= 0
    || currentUser?.roles.indexOf( "admin" ) >= 0;
  const isAdmin = currentUser?.roles.indexOf( "admin" ) >= 0;

  const tabLabels: Record<string, string> = {
    map: I18n.t( "map" ),
    articles: I18n.t( "about" ),
    highlights: I18n.t( "trends" ),
    interactions: I18n.t( "interactions" ),
    taxonomy: I18n.t( "taxonomy" ),
    status: I18n.t( "status" ),
    similar: speciesOrLower ? I18n.t( "similar_species" ) : I18n.t( "similar_taxa" ),
    identifications: I18n.t( "identifications" )
  };

  const drawerItems: Array<{
    value?: string;
    label?: string;
    href?: string;
    onClick?: ( ) => void;
    separator?: boolean;
    icon?: string;
  }> = [
    { value: "map", label: tabLabels.map },
    { value: "articles", label: tabLabels.articles },
    ...( !speciesOrLower ? [{ value: "highlights", label: tabLabels.highlights }] : [] ),
    ...( speciesOrLower && test === "interactions"
      ? [{ value: "interactions", label: tabLabels.interactions }] : [] ),
    { value: "taxonomy", label: tabLabels.taxonomy },
    ...( speciesOrLower ? [{ value: "status", label: tabLabels.status }] : [] ),
    ...( genusOrSpecies ? [{ value: "similar", label: tabLabels.similar }] : [] ),
    ...( currentUser?.canViewHelpfulIDTips( ) && speciesOrLower
      ? [{ value: "identifications", label: tabLabels.identifications }] : [] )
  ];

  let curationTab: React.ReactNode;

  if ( currentUser?.privilegedWith( "interaction" ) ) {
    drawerItems.push( { separator: true } );
    drawerItems.push( {
      href: `/taxa/${taxon.id}/flags/new`,
      label: I18n.t( "flag_for_curation" ),
      icon: "fa-flag"
    } );
    if ( flagsCount > 0 ) {
      drawerItems.push( {
        href: `/taxa/${taxon.id}/flags`,
        label: `${I18n.t( "view_flags" )} (${flagsCount})`,
        icon: "fa-flag-checkered"
      } );
    }
    if ( taxon.photos_locked && !isAdmin ) {
      drawerItems.push( {
        label: I18n.t( "photos_locked" ),
        icon: "fa-picture-o"
      } );
    } else if ( !currentUser.content_creation_restrictions ) {
      drawerItems.push( {
        onClick: ( ) => showPhotoChooserModal( ),
        label: I18n.t( "edit_photos" ),
        icon: "fa-picture-o"
      } );
    }
    if ( isCurator && taxon.rank_level <= 10 ) {
      drawerItems.push( taxon.atlas_id ? {
        href: `/atlases/${taxon.atlas_id}`,
        label: I18n.t( "edit_atlas" ),
        icon: "fa-globe"
      } : {
        href: `/atlases/new?taxon_id=${taxon.id}`,
        label: I18n.t( "create_an_atlas" ),
        icon: "fa-globe"
      } );
    }
    if ( isCurator ) {
      drawerItems.push( {
        href: `/taxa/${taxon.id}/edit`,
        label: I18n.t( "edit_taxon" ),
        icon: "fa-pencil"
      } );
    }
    drawerItems.push( {
      href: `/taxa/${taxon.id}/history`,
      label: I18n.t( "history" ),
      icon: "fa-history"
    } );

    let atlasItem: React.ReactNode;
    if ( isCurator && taxon.rank_level <= 10 ) {
      atlasItem = taxon.atlas_id ? (
        <MenuItem eventKey="edit-atlas" href={`/atlases/${taxon.atlas_id}`}>
          <i className="fa fa-globe" />
          { " " }
          { I18n.t( "edit_atlas" ) }
        </MenuItem>
      ) : (
        <MenuItem eventKey="new-atlas" href={`/atlases/new?taxon_id=${taxon.id}`}>
          <i className="fa fa-globe" />
          { " " }
          { I18n.t( "create_an_atlas" ) }
        </MenuItem>
      );
    }

    let taxonPhotosItem: React.ReactNode;
    if ( taxon.photos_locked && !isAdmin ) {
      taxonPhotosItem = (
        <MenuItem
          className="disabled"
          title={I18n.t( "photos_locked_desc" )}
          eventKey="edit-photos-locked"
        >
          <i className="fa fa-picture-o" />
          { " " }
          { I18n.t( "photos_locked" ) }
        </MenuItem>
      );
    } else if ( !currentUser.content_creation_restrictions ) {
      taxonPhotosItem = (
        <MenuItem eventKey="edit-photos">
          <i className="fa fa-picture-o" />
          { " " }
          { I18n.t( "edit_photos" ) }
        </MenuItem>
      );
    }

    curationTab = (
      <li className="curation-tab">
        <Dropdown
          id="curation-dropdown"
          pullRight
          onSelect={( eventKey: any ) => {
            switch ( eventKey ) {
              case "add-flag":
                window.location.href = `/taxa/${taxon.id}/flags/new`;
                break;
              case "view-flags":
                window.location.href = `/taxa/${taxon.id}/flags`;
                break;
              case "edit-photos":
                showPhotoChooserModal( );
                break;
              case "edit-photos-locked":
                break;
              case "edit-atlas":
                window.location.href = `/atlases/${taxon.atlas_id}`;
                break;
              case "new-atlas":
                window.location.href = `/atlases/new?taxon_id=${taxon.id}`;
                break;
              case "history":
                window.location.href = `/taxa/${taxon.id}/history`;
                break;
              default:
                window.location.href = `/taxa/${taxon.id}/edit`;
            }
          }}
        >
          <Dropdown.Toggle>
            <i className="fa fa-cog" />
            { " " }
            { I18n.t( "curation" ) }
          </Dropdown.Toggle>
          <Dropdown.Menu>
            <MenuItem eventKey="add-flag" href={`/taxa/${taxon.id}/flags/new`}>
              <i className="fa fa-flag" />
              { " " }
              { I18n.t( "flag_for_curation" ) }
            </MenuItem>
            <MenuItem
              className={flagsCount > 0 ? "" : "hidden"}
              eventKey="view-flags"
              href={`/taxa/${taxon.id}/flags`}
            >
              <i className="fa fa-flag-checkered" />
              { " " }
              { I18n.t( "view_flags" ) }
              { " " }
              <span className="text-muted">{ `(${flagsCount})` }</span>
            </MenuItem>
            { taxonPhotosItem }
            { atlasItem }
            <MenuItem
              className={isCurator ? "" : "hidden"}
              eventKey="edit-taxon"
              href={`/taxa/${taxon.id}/edit`}
            >
              <i className="fa fa-pencil" />
              { " " }
              { I18n.t( "edit_taxon" ) }
            </MenuItem>
            <MenuItem eventKey="history" href={`/taxa/${taxon.id}/history`}>
              <i className="fa fa-history" />
              { " " }
              { I18n.t( "history" ) }
            </MenuItem>
          </Dropdown.Menu>
        </Dropdown>
      </li>
    );
  }

  return (
    <div className="TaxonPageTabs" ref={containerRef}>
      <TabDrawer
        selectedValue={chosenTab}
        selectedLabel={tabLabels[chosenTab]}
        items={drawerItems}
        onChange={choseTab}
      />
      <Grid>
        <Row>
          <Col xs={12}>
            <ul id="main-tabs" className="nav nav-tabs" role="tablist">
              <li role="presentation" className={chosenTab === "map" ? "active" : ""}>
                <a href="#map-tab" role="tab" data-toggle="tab">{ I18n.t( "map" ) }</a>
              </li>
              <li role="presentation" className={chosenTab === "articles" ? "active" : ""}>
                <a href="#articles-tab" role="tab" data-toggle="tab">{ I18n.t( "about" ) }</a>
              </li>
              <li
                role="presentation"
                className={`${speciesOrLower ? "hidden" : ""} ${chosenTab === "highlights" ? "active" : ""}`}
              >
                <a href="#highlights-tab" role="tab" data-toggle="tab">
                  { I18n.t( "trends" ) }
                </a>
              </li>
              { test === "interactions" && (
                <li
                  role="presentation"
                  className={`${speciesOrLower ? "" : "hidden"} ${chosenTab === "interactions" ? "active" : ""}`}
                >
                  <a href="#interactions-tab" role="tab" data-toggle="tab">
                    { I18n.t( "interactions" ) }
                  </a>
                </li>
              ) }
              <li role="presentation" className={chosenTab === "taxonomy" ? "active" : ""}>
                <a href="#taxonomy-tab" role="tab" data-toggle="tab">{ I18n.t( "taxonomy" ) }</a>
              </li>
              <li
                role="presentation"
                className={`${speciesOrLower ? "" : "hidden"} ${chosenTab === "status" ? "active" : ""}`}
              >
                <a href="#status-tab" role="tab" data-toggle="tab">{ I18n.t( "status" ) }</a>
              </li>
              <li
                role="presentation"
                className={`${genusOrSpecies ? "" : "hidden"} ${chosenTab === "similar" ? "active" : ""}`}
              >
                <a href="#similar-tab" role="tab" data-toggle="tab">
                  { speciesOrLower ? I18n.t( "similar_species" ) : I18n.t( "similar_taxa" ) }
                </a>
              </li>
              { currentUser?.canViewHelpfulIDTips( ) && (
                <li
                  role="presentation"
                  className={`${speciesOrLower ? "" : "hidden"} ${chosenTab === "identifications" ? "active" : ""}`}
                >
                  <a href="#identifications-tab" role="tab" data-toggle="tab">
                    { I18n.t( "identifications" ) }
                  </a>
                </li>
              ) }
              { curationTab }
            </ul>
          </Col>
        </Row>
      </Grid>
      <div id="main-tabs-content" className="tab-content">
        <div
          role="tabpanel"
          className={`tab-pane ${chosenTab === "map" ? "active" : ""} vanilla`}
          id="map-tab"
        >
          <LazyLoad debounce={false} offset={100}>
            <TaxonPageMapContainer />
          </LazyLoad>
          <LazyLoad debounce={false} minHeight={120} offset={100}>
            <RecentObservationsContainer />
          </LazyLoad>
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${chosenTab === "articles" ? "active" : ""}`}
          id="articles-tab"
        >
          <ArticlesTabContainer />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${speciesOrLower ? "hidden" : ""} ${chosenTab === "highlights" ? "active" : ""}`}
          id="highlights-tab"
        >
          <HighlightsTabContainer />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${speciesOrLower ? "" : "hidden"} ${chosenTab === "interactions" ? "active" : ""}`}
          id="interactions-tab"
        >
          <InteractionsTabContainer />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${chosenTab === "taxonomy" ? "active" : ""}`}
          id="taxonomy-tab"
        >
          <TaxonomyTabContainer />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${speciesOrLower ? "" : "hidden"} ${chosenTab === "status" ? "active" : ""}`}
          id="status-tab"
        >
          <StatusTab
            currentUser={currentUser}
            taxon={taxon}
            statuses={taxon.conservationStatuses}
            listedTaxaCount={taxon.listed_taxa_count}
            listedTaxa={_.filter( taxon.listed_taxa, lt => lt.establishment_means )}
          />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${genusOrSpecies ? "" : "hidden"} ${chosenTab === "similar" ? "active" : ""}`}
          id="similar-tab"
        >
          <SimilarTabContainer />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${speciesOrLower ? "" : "hidden"} ${chosenTab === "identifications" ? "active" : ""}`}
          id="identifications-tab"
        >
          <IdentificationsTabContainer />
        </div>
      </div>
    </div>
  );
};

export default TaxonPageTabs;
