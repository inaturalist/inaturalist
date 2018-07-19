import React, { Component } from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col, Modal, Button } from "react-bootstrap";
/* global SITE */
/* global iNaturalist */

class LicensingModal extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.save = this.save.bind( this );
  }

  close( ) {
    this.props.setLicensingModalState( { show: false } );
  }

  save( ) {
    const selectedLicense = $( ".LicensingModal input:checked" ).attr( "value" ) || "";
    const makeDefault = $( ".LicensingModal #make_default" ).is( ":checked" );
    const updatePast = $( ".LicensingModal #update_past" ).is( ":checked" );
    const obsAttrs = { license: selectedLicense };
    if ( makeDefault ) {
      obsAttrs.make_license_default = true;
    }
    if ( updatePast ) {
      obsAttrs.make_licenses_same = true;
    }
    this.props.updateObservation( obsAttrs );
    this.props.setAttributes( { license_code: selectedLicense.toLowerCase( ) } );
    if ( makeDefault ) {
      const updatedUser = Object.assign( { }, this.props.config.currentUser, {
        preferred_observation_license: selectedLicense.toLowerCase( )
      } );
      this.props.setConfig( { currentUser: updatedUser } );
    }
    this.close( );
  }

  render( ) {
    const { observation, config } = this.props;
    if ( !observation || !observation.user || !config.currentUser ||
         config.currentUser.id !== observation.user.id ) {
      return ( <div /> );
    }
    const preferred = config.currentUser.preferred_observation_license;
    const inatLicenses = iNaturalist.Licenses;
    return (
      <Modal
        show={ this.props.show }
        className="LicensingModal"
        onHide={ this.close }
      >
        <Modal.Body>
          <h4>{ I18n.t( "edit_license" ) }</h4>
          <p
            dangerouslySetInnerHTML={ {
              __html: I18n.t( "views.users.edit.licensing_desc_html", { site_name: SITE.name } )
            } }
          />
          <Grid>
            <Row>
              <Col xs={6} className="license-col">
                <div className="field license_field">
                  <input
                    id="license_cc0"
                    type="radio"
                    value="CC0"
                    name="license"
                    defaultChecked={ observation.license_code === "cc0" }
                  />
                  <label htmlFor="license_cc0">
                    <img src={ inatLicenses.cc0.icon_large } alt="Cc0" />
                    { I18n.t( "cc_0_name" ) }
                    { preferred === "cc0" ? `(${I18n.t( "your_default" )})` : "" }
                  </label>
                </div>
                <div className="info">
                  <div className="preferred">
                    { I18n.t( "good_choice_for_sharing" ) }
                  </div>
                  { I18n.t( "cc_0_description" ) } <a
                    className="readmore"
                    target="_blank"
                    href="http://creativecommons.org/publicdomain/zero/1.0/"
                  >{ I18n.t( "view_license" ) }</a>
                </div>
              </Col>
              <Col xs={6} className="license-col">
                <div className="field license_field">
                  <input
                    id="license_cc-by"
                    type="radio"
                    value="CC-BY"
                    name="license"
                    defaultChecked={ observation.license_code === "cc-by" }
                  />
                  <label htmlFor="license_cc-by">
                    <img src={ inatLicenses["cc-by"].icon_large } alt="Cc by" />
                    { I18n.t( "cc_by_name" ) }
                    { preferred === "cc-by" ? `(${I18n.t( "your_default" )})` : "" }
                  </label>
                </div>
                <div className="info">
                  <div className="preferred">
                    { I18n.t( "good_choice_for_sharing" ) }
                  </div>
                  { I18n.t( "cc_by_description" ) } <a
                    className="readmore"
                    target="_blank"
                    href="http://creativecommons.org/licenses/by/4.0/"
                  >{ I18n.t( "view_license" ) }</a>
                </div>
              </Col>
            </Row>
            <Row>
              <Col xs={6} className="license-col">
                <div className="field license_field">
                  <input
                    id="license_cc-by-nc"
                    type="radio"
                    value="CC-BY-NC"
                    name="license"
                    defaultChecked={ observation.license_code === "cc-by-nc" }
                  />
                  <label htmlFor="license_cc-by-nc">
                    <img src={ inatLicenses["cc-by-nc"].icon_large } alt="Cc by nc" />
                    { I18n.t( "cc_by_nc_name" ) }
                    { preferred === "cc-by-nc" ? `(${I18n.t( "your_default" )})` : "" }
                  </label>
                </div>
                <div className="info">
                  <div className="preferred">
                    { I18n.t( "good_choice_for_sharing" ) }
                  </div>
                  { I18n.t( "cc_by_nc_description" ) } <a
                    className="readmore"
                    target="_blank"
                    href="http://creativecommons.org/licenses/by-nc/4.0/"
                  >{ I18n.t( "view_license" ) }</a>
                </div>
              </Col>
              <Col xs={6} className="license-col">
                <div className="field license_field">
                  <input
                    id="license_cc-by-sa"
                    type="radio"
                    value="CC-BY-SA"
                    name="license"
                    defaultChecked={ observation.license_code === "cc-by-sa" }
                  />
                  <label htmlFor="license_cc-by-sa">
                    <img src={ inatLicenses["cc-by-sa"].icon_large } alt="Cc by sa" />
                    { I18n.t( "cc_by_sa_name" ) }
                    { preferred === "cc-by-sa" ? `(${I18n.t( "your_default" )})` : "" }
                  </label>
                </div>
                <div className="info">
                  { I18n.t( "cc_by_sa_description" ) } <a
                    className="readmore"
                    target="_blank"
                    href="http://creativecommons.org/licenses/by-sa/4.0/"
                  >{ I18n.t( "view_license" ) }</a>
                </div>
              </Col>
            </Row>
            <Row>
              <Col xs={6} className="license-col">
                <div className="field license_field">
                  <input
                    id="license_cc-by-nd"
                    type="radio"
                    value="CC-BY-ND"
                    name="license"
                    defaultChecked={ observation.license_code === "cc-by-nd" }
                  />
                  <label htmlFor="license_cc-by-nd">
                    <img src={ inatLicenses["cc-by-nd"].icon_large } alt="Cc by nd" />
                    { I18n.t( "cc_by_nd_name" ) }
                    { preferred === "cc-by-nd" ? `(${I18n.t( "your_default" )})` : "" }
                  </label>
                </div>
                <div className="info">
                  { I18n.t( "cc_by_nd_description" ) } <a
                    className="readmore"
                    target="_blank"
                    href="http://creativecommons.org/licenses/by-nd/4.0/"
                  >{ I18n.t( "view_license" ) }</a>
                </div>
              </Col>
              <Col xs={6} className="license-col">
                <div className="field license_field">
                  <input
                    id="license_cc-by-nc-sa"
                    type="radio"
                    value="CC-BY-NC-SA"
                    name="license"
                    defaultChecked={ observation.license_code === "cc-by-nc-sa" }
                  />
                  <label htmlFor="license_cc-by-nc-sa">
                    <img src={ inatLicenses["cc-by-nc-sa"].icon_large } alt="Cc by nc sa" />
                    { I18n.t( "cc_by_nc_sa_name" ) }
                    { preferred === "cc-by-nc-sa" ? `(${I18n.t( "your_default" )})` : "" }
                  </label>
                </div>
                <div className="info">
                  { I18n.t( "cc_by_nc_sa_description" ) } <a
                    className="readmore"
                    target="_blank"
                    href="http://creativecommons.org/licenses/by-nc-sa/4.0/"
                  >{ I18n.t( "view_license" ) }</a>
                </div>
              </Col>
            </Row>
            <Row>
              <Col xs={6} className="license-col">
                <div className="field license_field">
                  <input
                    id="license_cc-by-nc-nd"
                    type="radio"
                    value="CC-BY-NC-ND"
                    name="license"
                    defaultChecked={ observation.license_code === "cc-by-nc-nd" }
                  />
                  <label htmlFor="license_cc-by-nc-nd">
                    <img src={ inatLicenses["cc-by-nc-nd"].icon_large } alt="Cc by nc nd" />
                    { I18n.t( "cc_by_nc_nd_name" ) }
                    { preferred === "cc-by-nc-nd" ? `(${I18n.t( "your_default" )})` : "" }
                  </label>
                </div>
                <div className="info">
                  { I18n.t( "cc_by_nc_nd_description" ) } <a
                    className="readmore"
                    target="_blank"
                    href="http://creativecommons.org/licenses/by-nc-nd/4.0/"
                  >{ I18n.t( "view_license" ) }</a>
                </div>
              </Col>
            </Row>
            <Row>
              <Col xs={6} className="license-col">
                <div className="field license_field">
                  <input
                    id="license_reserved"
                    type="radio"
                    name="license"
                    defaultChecked={ !observation.license_code }
                  />
                  <label htmlFor="license_reserved">
                    { I18n.t( "no_license_all_rights_reserved" ) }
                    { !preferred ? `(${I18n.t( "your_default" )})` : "" }
                  </label>
                </div>
                <div className="info">
                  { I18n.t( "you_retain_full_copyright", { site_name: SITE.name } ) }
                </div>
              </Col>
            </Row>
          </Grid>
        </Modal.Body>
        <Modal.Footer>
          <div className="buttons">
            <input type="checkbox" id="make_default" />
            <label htmlFor="make_default">
              { I18n.t( "make_this_your_default_license", { type: I18n.t( "observation_" ) } ) }
            </label>
            <input type="checkbox" id="update_past" />
            <label htmlFor="update_past">
              { I18n.t( "update_past", { type: I18n.t( "observations_" ) } ) }
            </label>
            <Button bsStyle="default" onClick={ this.close }>
              { I18n.t( "cancel" ) }
            </Button>
            <Button bsStyle="primary" onClick={ this.save }>
              { I18n.t( "set_license" ) }
            </Button>
          </div>
        </Modal.Footer>
      </Modal>
    );
  }
}

LicensingModal.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  setAttributes: PropTypes.func,
  setConfig: PropTypes.func,
  setLicensingModalState: PropTypes.func,
  updateObservation: PropTypes.func,
  show: PropTypes.bool
};

export default LicensingModal;
