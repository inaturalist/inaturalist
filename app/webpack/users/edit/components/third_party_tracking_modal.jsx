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
      <label htmlFor="third_party_tracking">{I18n.t( "third_party_tracking" )}</label>
      <p>{I18n.t( "prefers_no_tracking_label_desc_we_use" )}</p>
      <li>
        <span
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "users.views.edit.prefers_no_tracking_label_desc_we_use_google_html" )
          }}
        />
      </li>
      <li><a href="https://newrelic.com/">New Relic</a></li>
      <p />
      <p>{I18n.t( "users.views.edit.prefers_no_tracking_label_desc_info_we_share" )}</p>
      <li>
        <span
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "users.views.edit.prefers_no_tracking_label_desc_info_we_share_ip_addresses_html" )
          }}
        />
      </li>
      <li>
        {I18n.t( "users.views.edit.prefers_no_tracking_label_desc_info_we_share_browser_details" )}
      </li>
      <li>
        {I18n.t( "users.views.edit.prefers_no_tracking_label_desc_info_we_share_crash_details" )}
      </li>
      <li>
        {I18n.t( "users.views.edit.prefers_no_tracking_label_desc_info_we_share_device_details" )}
      </li>
      <li>
        <span
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "users.views.edit.prefers_no_tracking_label_desc_value_html" )
          }}
        />
      </li>
      <p />
      <p>{I18n.t( "users.views.edit.prefers_no_tracking_label_desc_limits" )}</p>
    </Modal.Body>
  </Modal>
);

ThirdPartyTrackingModal.propTypes = {
  show: PropTypes.bool,
  onClose: PropTypes.func
};

export default ThirdPartyTrackingModal;
