import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";

const ThirdPartyTrackingModal = ( { show, onClose } ) => (
  <Modal
    show={show}
    className="ThirdPartyTrackingModal"
    onHide={onClose}
  >
    <Modal.Header closeButton>
      <Modal.Title>{I18n.t( "third_party_tracking" )}</Modal.Title>
    </Modal.Header>
    <Modal.Body>
      <p>
        <strong>
          {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_we_use" )}
        </strong>
      </p>
      <ul>
        <li>
          <strong>
            <span
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.prefers_no_tracking_label_desc_we_use_google_html" )
              }}
            />
          </strong>
        </li>
        <li className="stacked">
          <strong>
            <a href="https://newrelic.com/">New Relic</a>
          </strong>
        </li>
      </ul>
      <p>
        <strong>
          {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share" )}
        </strong>
      </p>
      <ul>
        <li>
          <strong>
            <span
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html:
                  I18n.t(
                    "views.users.edit.prefers_no_tracking_label_desc_info_we_share_ip_addresses_html"
                  )
              }}
            />
          </strong>
        </li>
        <li>
          <strong>
            {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_browser_details" )}
          </strong>
        </li>
        <li>
          <strong>
            {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_crash_details" )}
          </strong>
        </li>
        <li>
          <strong>
            {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_device_details" )}
          </strong>
        </li>
        <li className="stacked">
          <strong>
            <span
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.prefers_no_tracking_label_desc_value_html" )
              }}
            />
          </strong>
        </li>
      </ul>
      <p>{I18n.t( "views.users.edit.prefers_no_tracking_label_desc_limits" )}</p>
    </Modal.Body>
  </Modal>
);

ThirdPartyTrackingModal.propTypes = {
  show: PropTypes.bool,
  onClose: PropTypes.func
};

export default ThirdPartyTrackingModal;
