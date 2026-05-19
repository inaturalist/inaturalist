import React, { useEffect, useRef } from "react";
import {
  Dropdown,
  MenuItem
} from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import TaxonPageMapContainer from "../containers/taxon_page_map_container";
import StatusTab, { ConservationStatus, ListedTaxon } from "./status_tab";
import TaxonomyTabContainer from "../containers/taxonomy_tab_container";
import ArticlesTabContainer from "../containers/articles_tab_container";
import InteractionsTabContainer from "../containers/interactions_tab_container";
import HighlightsTabContainer from "../containers/highlights_tab_container";
import SimilarTabContainer from "../containers/similar_tab_container";
import IdentificationsTabContainer from "../containers/identifications_tab_container";
import RecentObservationsContainer from "../containers/recent_observations_container";
import TabDrawer from "../../../shared/components/tab_drawer";
import type { Taxon as BaseTaxon, CurrentUser as BaseCurrentUser } from "../../../shared/types";

const MAIN_TAB_VALUES = new Set( [
  "map", "articles", "highlights", "interactions",
  "taxonomy", "status", "similar", "identifications"
] );

// On this page the taxon always has a rank_level and the user's curation methods are present.
type Taxon = BaseTaxon & {
  rank_level: number;
  conservationStatuses?: ConservationStatus[];
  listed_taxa?: ListedTaxon[];
  listed_taxa_count?: number;
};
type CurrentUser = BaseCurrentUser & {
  roles: string[];
  canViewHelpfulIDTips: ( ) => boolean;
  privilegedWith: ( perm: string ) => boolean;
};

interface Props {
  taxon: Taxon;
  currentUser?: CurrentUser;
  chosenTab?: string;
  loadDataForTab: ( tab: string ) => void;
  choseTab: ( tab: string ) => void;
  showPhotoChooserModal: ( ) => void;
}

interface DrawerItem {
  value: string;
  label?: string;
  href?: string;
  onClick?: ( ) => void;
  separator?: boolean;
  icon?: string;
  visible?: boolean;
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

  useEffect( ( ) => {
    const currTaxonId = taxon ? taxon.id : null;
    if ( prevTaxonIdRef.current !== null && prevTaxonIdRef.current !== currTaxonId ) {
      loadDataForTab( chosenTab );
    }
    prevTaxonIdRef.current = currTaxonId;
  }, [taxon?.id] );

  useEffect( ( ) => {
    if ( chosenTab === "map" && prevChosenTabRef.current !== "map" ) {
      const taxonMap = $( ".TaxonMap", containerRef.current );
      // If google wasn't initialized for some reason, doing any of this will
      // crash, and we can't use an ErrorBoundary in a callback like this
      if ( typeof google !== "undefined" ) {
        const mapInstance = taxonMap.data( "taxonMap" ) as object;
        google.maps.event.trigger( mapInstance, "resize" );
        taxonMap.taxonMap( taxonMap.data( "taxonMapOptions" ) );
      }
    }
    prevChosenTabRef.current = chosenTab;
  }, [chosenTab] );

  const { test } = $.deparam.querystring( );
  const speciesOrLower = taxon && taxon.rank_level <= 10;
  const genusOrSpecies = taxon && ( taxon.rank_level === 20 || taxon.rank_level === 10 );
  const flagsCount = taxon.flag_counts
    ? Number( taxon.flag_counts.resolved ?? 0 ) + Number( taxon.flag_counts.unresolved ?? 0 )
    : 0;
  const isCurator = !!currentUser?.roles.includes( "curator" )
    || !!currentUser?.roles.includes( "admin" );
  const isAdmin = !!currentUser?.roles.includes( "admin" );

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

  const tabItems: DrawerItem[] = [
    { value: "map", label: tabLabels.map },
    { value: "articles", label: tabLabels.articles },
    { value: "highlights", label: tabLabels.highlights, visible: !speciesOrLower },
    { value: "interactions", label: tabLabels.interactions, visible: !!( speciesOrLower && test === "interactions" ) },
    { value: "taxonomy", label: tabLabels.taxonomy },
    { value: "status", label: tabLabels.status, visible: !!speciesOrLower },
    { value: "similar", label: tabLabels.similar, visible: !!genusOrSpecies },
    { value: "identifications", label: tabLabels.identifications, visible: !!( currentUser?.canViewHelpfulIDTips( ) && speciesOrLower ) }
  ].filter( item => item.visible !== false );

  const curationItems: DrawerItem[] = currentUser?.privilegedWith( "interaction" ) ? [
    {
      value: "separator1",
      separator: true
    },
    {
      value: "flag-for-curation",
      href: `/taxa/${taxon.id}/flags/new`,
      label: I18n.t( "flag_for_curation" ),
      icon: "fa-flag"
    },
    {
      value: "view-flags",
      href: `/taxa/${taxon.id}/flags`,
      label: `${I18n.t( "view_flags" )} (${flagsCount})`,
      icon: "fa-flag-checkered",
      visible: flagsCount > 0
    },
    {
      value: "photos-locked",
      label: I18n.t( "photos_locked" ),
      icon: "fa-picture-o",
      visible: !!( taxon.photos_locked && !isAdmin )
    },
    {
      value: "edit-photos",
      onClick: ( ) => showPhotoChooserModal( ),
      label: I18n.t( "edit_photos" ),
      icon: "fa-picture-o",
      visible: !taxon.photos_locked && !currentUser.content_creation_restrictions
    },
    {
      value: "edit-atlas",
      href: `/atlases/${taxon.atlas_id}`,
      label: I18n.t( "edit_atlas" ),
      icon: "fa-globe",
      visible: isCurator && taxon.rank_level <= 10 && !!taxon.atlas_id
    },
    {
      value: "new-atlas",
      href: `/atlases/new?taxon_id=${taxon.id}`,
      label: I18n.t( "create_an_atlas" ),
      icon: "fa-globe",
      visible: isCurator && taxon.rank_level <= 10 && !taxon.atlas_id
    },
    {
      value: "edit-taxon",
      href: `/taxa/${taxon.id}/edit`,
      label: I18n.t( "edit_taxon" ),
      icon: "fa-pencil",
      visible: isCurator
    },
    {
      value: "history",
      href: `/taxa/${taxon.id}/history`,
      label: I18n.t( "history" ),
      icon: "fa-history"
    }
  ].filter( item => item.visible !== false ) : [];

  const drawerItems = [...tabItems, ...curationItems];

  const curationTab = curationItems.length > 0 ? (
    <li className="curation-tab">
      <Dropdown
        id="curation-dropdown"
        pullRight
        onSelect={( eventKey: string ) => {
          if ( eventKey === "edit-photos" ) showPhotoChooserModal( );
        }}
      >
        <Dropdown.Toggle>
          <i className="fa fa-cog" />
          { " " }
          { I18n.t( "curation" ) }
        </Dropdown.Toggle>
        <Dropdown.Menu>
          { curationItems.map( item => {
            if ( item.separator ) return null;

            return (
              <MenuItem
                key={item.value}
                eventKey={item.value}
                href={item.href}
                className={item.value === "photos-locked" ? "disabled" : undefined}
                title={item.value === "photos-locked" ? I18n.t( "photos_locked_desc" ) : undefined}
              >
                <i className={`fa ${item.icon}`} />
                { " " }
                { item.label }
              </MenuItem>
            );
          } ) }
        </Dropdown.Menu>
      </Dropdown>
    </li>
  ) : null;

  return (
    <div className="TaxonPageTabs" ref={containerRef}>
      <TabDrawer
        selectedValue={chosenTab}
        selectedLabel={tabLabels[chosenTab]}
        items={drawerItems}
        onChange={choseTab}
      />
      <ul id="main-tabs" className="nav nav-tabs" role="tablist">
        { drawerItems
          .filter( item => !item.separator && MAIN_TAB_VALUES.has( item.value ) )
          .map( item => (
            <li key={item.value} role="presentation" className={chosenTab === item.value ? "active" : ""}>
              <a
                href={`#${item.value}-tab`}
                role="tab"
                onClick={e => {
                  e.preventDefault( );
                  choseTab( item.value );
                }}
              >
                { item.label }
              </a>
            </li>
          ) )}
        { curationTab }
      </ul>
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
            listedTaxa={taxon.listed_taxa?.filter( lt => lt.establishment_means )}
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
