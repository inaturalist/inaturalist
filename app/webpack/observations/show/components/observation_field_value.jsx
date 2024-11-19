import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Popover, OverlayTrigger } from "react-bootstrap";
import UserText from "../../../shared/components/user_text";
import SplitTaxon from "../../../shared/components/split_taxon";

class ObservationFieldValue extends React.Component {
  render( ) {
    const { ofv, config, observation } = this.props;
    if (
      !observation
      || !ofv
      || !ofv.observation_field
      || !observation.user
    ) { return ( <div /> ); }
    const currentUser = config && config.currentUser;
    const pref = observation.user.preferences.prefers_observation_fields_by;
    const viewerIsCurator = currentUser && currentUser.roles && (
      currentUser.roles.indexOf( "curator" ) >= 0
    );
    // You can edit an existing field if you are the observer, if you are a
    // curator and the observer allows fields from curators, or if the user
    // allows fields from anyone
    const editAllowed = (
      currentUser
      && observation.user
      && (
        currentUser.id === observation.user.id
        || ( pref === "curators" && viewerIsCurator )
        || pref === "anyone"
        || _.isUndefined( pref )
      )
    );
    // You can delete an existing field if you added it or if you are the
    // observer
    const deleteAllowed = (
      currentUser
      && observation.user
      && ofv.user
      && (
        currentUser.id === observation.user.id
        || ( ofv && currentUser.id === ofv.user.id )
      )
    );
    let { value } = ofv;
    let loading;
    if ( ofv.api_status ) {
      loading = ( <div className="loading_spinner" /> );
    }
    if ( ofv.observation_field.datatype === "dna" ) {
      value = (
        <div className="dna">
          { ofv.value }
          { " " }
          { loading }
        </div>
      );
    } else if ( ofv.observation_field.datatype === "text" ) {
      value = (
        <div className="value">
          <UserText text={value} />
          { " " }
          { loading }
        </div>
      );
    } else {
      if ( ofv.observation_field.datatype === "taxon" && ofv.taxon ) {
        value = (
          <SplitTaxon
            taxon={ofv.taxon}
            url={`/taxa/${ofv.taxon.id}`}
            user={config.currentUser}
          />
        );
      }
      value = (
        <div className="value">
          { value }
          { " " }
          { loading }
        </div>
      );
    }
    let info;
    if ( ofv.observation_field.description ) {
      info = (
        <div className="info">
          <div className="header">{ `${I18n.t( "info" )}:` }</div>
          <div className="desc">
            { ofv.observation_field.description }
          </div>
        </div>
      );
    }
    let editOptions;
    if ( editAllowed || deleteAllowed ) {
      editOptions = (
        <div className="edit">
          { editAllowed && (
            <div>
              <button
                type="button"
                className="btn btn-nostyle"
                onClick={( ) => {
                  if ( ofv.api_status ) { return; }
                  this.props.setEditingFieldValue( ofv );
                }}
              >
                { I18n.t( "edit" ) }
              </button>
            </div>
          ) }
          { deleteAllowed && (
            <div>
              <button
                type="button"
                className="btn btn-nostyle"
                onClick={( ) => {
                  if ( ofv.api_status ) { return; }
                  this.props.removeObservationFieldValue( ofv.uuid );
                }}
              >
                { I18n.t( "delete" ) }
              </button>
            </div>
          ) }
        </div>
      );
    }
    let addedBy;
    if ( ofv.user ) {
      addedBy = (
        <div className="added-by">
          <div className="view">
            { I18n.t( "label_colon", { label: I18n.t( "added_by" ) } ) }
          </div>
          <a href={`/people/${ofv.user.login}`}>
            { ofv.user.login }
          </a>
        </div>
      );
    }
    const popover = (
      <Popover
        id={`field-popover-${ofv.uuid}`}
        className="ObservationFieldPopover"
      >
        { info }
        { addedBy }
        { editOptions }
        <div className="contents">
          <div className="view">
            { I18n.t( "label_colon", { label: I18n.t( "view" ) } ) }
          </div>
          <div className="search">
            <a href={`/observations?verifiable=any&place_id=any&field:${ofv.observation_field.name}=${ofv.value}`}>
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "observations_with_this_field_and_value" ) }</span>
            </a>
          </div>
          <div className="search">
            <a href={`/observations?verifiable=any&place_id=any&field:${ofv.observation_field.name}`}>
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "observations_with_this_field" ) }</span>
            </a>
          </div>
          <div className="search">
            <a href={`/observations?verifiable=any&place_id=any&without_field=${ofv.observation_field.name}`}>
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "observations_without_this_field" ) }</span>
            </a>
          </div>
          <div className="search">
            <a href={`/observation_fields/${ofv.observation_field.id}`}>
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "observation_field_details" ) }</span>
            </a>
          </div>
        </div>
      </Popover>
    );
    return (
      <div className="ObservationFieldValue" key={`ofv-${ofv.uuid || ofv.observation_field.id}`}>
        <OverlayTrigger
          trigger="click"
          rootClose
          placement="top"
          animation={false}
          overlay={popover}
        >
          <div className="field">
            { I18n.t( "label_colon", { label: ofv.observation_field.name } ) }
          </div>
        </OverlayTrigger>
        <div className="value">{ value }</div>
      </div>
    );
  }
}

ObservationFieldValue.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  ofv: PropTypes.object,
  removeObservationFieldValue: PropTypes.func,
  setEditingFieldValue: PropTypes.func
};

export default ObservationFieldValue;
