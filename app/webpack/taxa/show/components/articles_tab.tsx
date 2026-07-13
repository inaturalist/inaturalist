import React from "react";
import _ from "lodash";
import type { Taxon, CurrentUser } from "../../../shared/types";

type TaxonWithVision = Taxon & { vision?: boolean };

interface TaxonLink {
  taxon_link: {
    id: number;
    site_title: string;
  };
  url: string;
}

interface Props {
  taxon: TaxonWithVision;
  description?: string;
  descriptionSource?: string;
  descriptionSourceUrl?: string;
  links?: TaxonLink[];
  currentUser?: CurrentUser;
}

const ArticlesTab = ( {
  taxon,
  description,
  descriptionSource,
  descriptionSourceUrl,
  links = [],
  currentUser
}: Props ) => {
  const isCurator = currentUser && currentUser.roles && (
    currentUser.roles.indexOf( "curator" ) >= 0
    || currentUser.roles.indexOf( "admin" ) >= 0
  );
  return (
    <div className="ArticlesTab">
      <div className="tab-row">
        <div className="tab-main">
          <h2
            className={`text-center ${description ? "hidden" : ""}`}
          >
            <i className="fa fa-refresh fa-spin" />
          </h2>
          <div className={description ? "" : "hidden"}>
            <h2>
              { I18n.t( "source_" ) }
              { " " }
              { descriptionSource }
              { " " }
              { descriptionSourceUrl && (
                <a href={descriptionSourceUrl} aria-label={I18n.t( "source_url" )}>
                  <i className="icon-link-external" />
                </a>
              ) }
            </h2>
            <div dangerouslySetInnerHTML={{ __html: description || "" }} />
          </div>
        </div>
        <div className="tab-side">
          <h2>{ I18n.t( "more_info_title" ) }</h2>
          <ul className="list-group iconified-list-group">
            { _.sortBy( links, l => _.lowerCase( l.taxon_link.site_title ) ).map( link => {
              const host = link.url.split( "/" )[2];
              return (
                <li
                  key={`taxon-links-${link.taxon_link.id}`}
                  className="list-group-item"
                >
                  <a
                    href={link.url}
                    style={{
                      backgroundImage: `url( 'https://www.google.com/s2/favicons?domain=${host}' )`
                    }}
                  >
                    { link.taxon_link.site_title }
                  </a>
                  { isCurator ? (
                    <a href={`/taxon_links/${link.taxon_link.id}/edit`} aria-label={I18n.t( "edit" )}>
                      <i className="fa fa-pencil" />
                    </a>
                  ) : null }
                </li>
              );
            } ) }
          </ul>
          { isCurator ? (
            <a
              href={`/taxon_links/new?taxon_id=${taxon.id}`}
              className="btn btn-primary btn-block"
            >
              <i className="icon-link" />
              { " " }
              { I18n.t( "add_link" ) }
            </a>
          ) : null }
          { taxon.rank === "species" && (
            <div className="computer-vision-status">
              <h2>{ I18n.t( "computer_vision_model" ) }</h2>
              { taxon.vision ? (
                <div>
                  <h3>
                    <span className="label label-success">
                      <i className="icon-sparkly-label" />
                      { " " }
                      { I18n.t( "computer_vision_model_included" ) }
                    </span>
                  </h3>
                  <p>
                    { I18n.t( "computer_vision_model_included_desc" ) }
                  </p>
                  <p dangerouslySetInnerHTML={{
                    __html: I18n.t( "geomodel_expected_nearby_label_is_derived", {
                      url: `/geo_model/${taxon.id}/explain`
                    } )
                  }}
                  />
                </div>
              ) : (
                <div>
                  <h3>
                    <span className="label label-default">
                      { I18n.t( "computer_vision_model_pending" ) }
                    </span>
                  </h3>
                  <p>
                    { I18n.t( "computer_vision_model_pending_desc2" ) }
                  </p>
                </div>
              ) }
            </div>
          ) }
        </div>
      </div>
    </div>
  );
};

export default ArticlesTab;
