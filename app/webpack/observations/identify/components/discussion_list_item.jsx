import React, { PropTypes } from "react";
import moment from "moment";
import SplitTaxon from "./split_taxon";
import { Button } from "react-bootstrap";
import _ from "lodash";

const DiscussionListItem = ( {
  user,
  body,
  createdAt,
  identification,
  className
} ) => {
  let ident;
  if ( identification ) {
    let taxonImageTag;
    const t = identification.taxon;
    if ( identification.taxon.defaultPhoto ) {
      taxonImageTag = (
        <img src={t.defaultPhoto.photoUrl()} className="taxon-image" />
      );
    } else if ( t.iconic_taxon_name ) {
      taxonImageTag = (
        <i
          className={`taxon-image icon icon-iconic-${t.iconic_taxon_name.toLowerCase( )}`}
        >
        </i>
      );
    } else {
      taxonImageTag = <i className="icon icon-iconic-unknown"></i>;
    }
    ident = (
      <div className="identification">
        { taxonImageTag }
        <SplitTaxon
          taxon={t}
          noParens
          url={`/taxa/${t.id}`}
        />
        <div className="actions">
          <Button bsSize="small">
            { _.capitalize( I18n.t( "agree" ) ) }
          </Button>
        </div>
      </div>
    );
  }
  return (
    <div className={`DiscussionListItem ${className}`}>
      <div className="clear">
        <a href={`/people/${user.login}`}>
          {user.login}
        </a>'s { identification ? I18n.t( "identification" ) : I18n.t( "comment" ) }
        <span className="date pull-right" title={createdAt}>
          { moment( createdAt ).fromNow( ) }
        </span>
      </div>
      { ident }
      <div className="body">
        { body }
      </div>
    </div>
  );
};

DiscussionListItem.propTypes = {
  user: PropTypes.object.isRequired,
  body: PropTypes.string,
  createdAt: React.PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.object
  ] ),
  identification: PropTypes.object,
  className: PropTypes.string
};

export default DiscussionListItem;
