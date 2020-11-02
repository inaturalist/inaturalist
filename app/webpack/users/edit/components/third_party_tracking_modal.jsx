import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";

const ThirdPartyTrackingModal = ( { show, onClose } ) => (
  <Modal
    show={show}
    className="ThirdPartyTrackingModal"
    onHide={onClose}
  >
    <Modal.Body>
      <label className="bold" htmlFor="third_party_tracking">{I18n.t( "third_party_tracking" )}</label>
      <button
        type="button"
        className="btn btn-nostyle"
        onClick={onClose}
      >
        <i className="fa fa-times text-muted hide-button fa-2x" aria-hidden="true" />
      </button>
      <p className="bold">{I18n.t( "views.users.edit.prefers_no_tracking_label_desc_we_use" )}</p>
      <li>
        <span
          className="bold"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.users.edit.prefers_no_tracking_label_desc_we_use_google_html" )
          }}
        />
      </li>
      <li><a href="https://newrelic.com/" className="bold">New Relic</a></li>
      <p />
      <p className="bold">{I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share" )}</p>
      <li>
        <span
          className="bold"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html:
              I18n.t(
                "views.users.edit.prefers_no_tracking_label_desc_info_we_share_ip_addresses_html"
              )
          }}
        />
      </li>
      <li className="bold">
        {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_browser_details" )}
      </li>
      <li className="bold">
        {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_crash_details" )}
      </li>
      <li className="bold">
        {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_device_details" )}
      </li>
      <li>
        <span
          className="bold"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.users.edit.prefers_no_tracking_label_desc_value_html" )
          }}
        />
      </li>
      <p />
      <p>{I18n.t( "views.users.edit.prefers_no_tracking_label_desc_limits" )}</p>
    </Modal.Body>
  </Modal>
);

ThirdPartyTrackingModal.propTypes = {
  show: PropTypes.bool,
  onClose: PropTypes.func
};

export default ThirdPartyTrackingModal;
