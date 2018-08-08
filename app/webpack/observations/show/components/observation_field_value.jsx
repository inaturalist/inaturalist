import React from "react";
import PropTypes from "prop-types";
import { Popover, OverlayTrigger } from "react-bootstrap";
import UserText from "../../../shared/components/user_text";
import SplitTaxon from "../../../shared/components/split_taxon";

class ObservationFieldValue extends React.Component {
  render( ) {
    const { ofv, config, observation } = this.props;
    if ( !observation || !ofv || !ofv.observation_field ) { return ( <div /> ); }
    const loggedIn = config && config.currentUser;
    let value = ofv.value;
    let loading;
    if ( ofv.api_status ) {
      loading = ( <div className="loading_spinner" /> );
    }
    if ( ofv.datatype === "dna" ) {
      value = ( <div className="dna">{ ofv.value } { loading }</div> );
    } else if ( ofv.datatype === "text" ) {
      value = ( <div className="value"><UserText text={ value } /> { loading }</div> );
    } else {
      if ( ofv.datatype === "taxon" && ofv.taxon ) {
        value = ( <SplitTaxon
          taxon={ ofv.taxon }
          url={ `/taxa/${ofv.taxon.id}` }
          user={ config.currentUser }
        /> );
      }
      value = ( <div className="value">{ value } { loading }</div> );
    }
    let info;
    if ( ofv.observation_field && ofv.observation_field.description ) {
      info = ( <div className="info">
        <div className="header">{ I18n.t( "info" ) }:</div>
        <div className="desc">
          { ofv.observation_field.description }
        </div>
      </div> );
    }
    let editOptions;
    if ( loggedIn ) {
      editOptions = ( <div className="edit">
        <div onClick={ ( ) => {
          if ( ofv.api_status ) { return; }
          this.props.setEditingFieldValue( ofv );
        } }
        >{ I18n.t( "edit" ) }</div>
        <div onClick={ ( ) => {
          if ( ofv.api_status ) { return; }
          this.props.removeObservationFieldValue( ofv.uuid );
        } }
        >{ I18n.t( "delete" ) }</div>
      </div> );
    }
    let addedBy;
    if ( ofv.user && ofv.user.id !== observation.user.id ) {
      addedBy = ( <div className="added-by">
        <div className="view">Added By:</div>
        <a href={ `/people/${ofv.user.login}` }>
          { ofv.user.login }
        </a>
      </div> );
    }
    const popover = (
      <Popover
        id={ `field-popover-${ofv.uuid}` }
        className="ObservationFieldPopover"
      >
        { info }
        { addedBy }
        { editOptions }
        <div className="contents">
          <div className="view">View:</div>
          <div className="search">
            <a href={ `/observations?field:${ofv.name}=${ofv.value}` }>
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "observations_with_this_field_and_value" ) }</span>
            </a>
          </div>
          <div className="search">
            <a href={ `/observations?field:${ofv.name}` }>
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "observations_with_this_field" ) }</span>
            </a>
          </div>
          <div className="search">
            <a href={ `/observation_fields/${ofv.observation_field.id}` }>
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "observation_field_details" ) }</span>
            </a>
          </div>
        </div>
      </Popover>
    );
    return (
      <div className="ObservationFieldValue" key={ `ofv-${ofv.uuid || ofv.observation_field.id}` }>
        <OverlayTrigger
          trigger="click"
          rootClose
          placement="top"
          animation={false}
          overlay={popover}
        >
          <div className="field">
            { ofv.name }:
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
