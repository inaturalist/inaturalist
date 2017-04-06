import React, { PropTypes } from "react";
import { Popover, OverlayTrigger } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { Glyphicon } from "react-bootstrap";

class ObservationFieldValue extends React.Component {
  render( ) {
    const { ofv, config } = this.props;
    if ( !ofv || !ofv.observation_field ) { return ( <div /> ); }
    const loggedIn = config && config.currentUser;
    let value = ofv.value;
    let loading;
    if ( ofv.api_status ) {
      loading = ( <div className="loading_spinner" /> );
    }
    if ( ofv.datatype === "dna" ) {
      value = ( <div className="dna">{ ofv.value } { loading }</div> );
    } else {
      if ( ofv.datatype === "taxon" && ofv.taxon ) {
        value = ( <SplitTaxon
          taxon={ ofv.taxon }
          url={ `/taxa/${ofv.taxon.id}` }
        /> );
      }
      value = ( <div className="value">{ value } { loading }</div> );
    }
    let info;
    if ( ofv.observation_field && ofv.observation_field.description ) {
      info = ( <div className="info">
        <div className="header">Info:</div>
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
        >Edit</div>
        <div onClick={ ( ) => {
          if ( ofv.api_status ) { return; }
          this.props.removeObservationFieldValue( ofv.uuid );
        } }
        >Delete</div>
      </div> );
    }
    const popover = (
      <Popover
        id={ `field-popover-${ofv.uuid}` }
        className="ObservationFieldPopover"
      >
        { info }
        { editOptions }
        <div className="contents">
          <div className="view">View:</div>
          <div className="search">
            <a href={ `/observations?field:${ofv.name}=${ofv.value}` }>
              <i className="fa fa-arrow-circle-o-right" />
              Observations with this field and value
            </a>
          </div>
          <div className="search">
            <a href={ `/observations?field:${ofv.name}` }>
              <i className="fa fa-arrow-circle-o-right" />
              Observations with this field
            </a>
          </div>
          <div className="search">
            <a href={ `/observation_fields/${ofv.observation_field.id}` }>
              <i className="fa fa-arrow-circle-o-right" />
              Observation field details
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
  ofv: PropTypes.object,
  removeObservationFieldValue: PropTypes.func,
  setEditingFieldValue: PropTypes.func
};

export default ObservationFieldValue;
