import React, { PropTypes } from "react";
import moment from "moment";
import { Button } from "react-bootstrap";
import _ from "lodash";
import SplitTaxon from "./split_taxon";
import UserText from "./user_text";

const DiscussionListItem = ( {
  user,
  body,
  createdAt,
  identification,
  className,
  agreeWith,
  hideAgree,
  onEdit,
  onDelete,
  currentUser
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
      taxonImageTag = <i className="taxon-image icon icon-iconic-unknown"></i>;
    }
    let actions;
    if ( !hideAgree ) {
      actions = (
        <div className="actions">
          <Button
            bsSize="xsmall"
            onClick={ function ( ) {
              agreeWith( {
                observation_id: identification.observation_id,
                taxon_id: identification.taxon.id
              } );
            } }
          >
            { _.capitalize( I18n.t( "agree" ) ) }
          </Button>
        </div>
      );
    }
    ident = (
      <div className={identification.current ? "identification" : "identification outdated"}>
        { taxonImageTag }
        <SplitTaxon
          taxon={t}
          noParens
          url={`/taxa/${t.id}`}
        />
        { actions }
      </div>
    );
  }
  let controls;
  if ( currentUser.id === user.id ) {
    controls = (
      <span className="controls">
        <a onClick={ ( ) => onEdit( ) }>{ I18n.t( "edit" ) }</a>
        &middot;
        <a onClick={ onDelete }>{ I18n.t( "delete" ) }</a>
      </span>
    );
  }
  return (
    <div className={`DiscussionListItem ${className}`}>
      <div className="clear">
        <a href={`/people/${user.login}`}>
          {user.login}
        </a>'s { identification ? I18n.t( "identification" ) : I18n.t( "comment" ) }
        { controls }
        <span className="date pull-right" title={createdAt}>
          { moment( createdAt ).local( ).fromNow( ) }
        </span>
      </div>
      { ident }
      <UserText text={body} className="body" />
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
  className: PropTypes.string,
  agreeWith: PropTypes.func,
  hideAgree: PropTypes.bool,
  onEdit: PropTypes.func,
  onDelete: PropTypes.func,
  currentUser: PropTypes.object
};

export default DiscussionListItem;
