import React from "react";
import PropTypes from "prop-types";
import DonateContent from "./donate_content";
import DonateContent2021 from "./donate_content_2021";
import DonateContent2022 from "./donate_content_2022";
import StoreContent from "./store_content";
import StoreContent2021 from "./store_content_2021";

const Donate = ( {
  data,
  defaultSiteId,
  forDonor,
  forMonthlyDonor,
  site,
  sites,
  year
} ) => {
  let content;
  // https://gist.github.com/59naga/ed6714519284d36792ba
  const isTouchDevice = navigator.userAgent.match(
    /(Android|webOS|iPhone|iPad|iPod|BlackBerry|Windows Phone)/i
  ) !== null;
  if ( year === 2021 ) {
    content = (
      <>
        <StoreContent2021 isTouchDevice={isTouchDevice} />
        <DonateContent2021 forDonor={forDonor} year={year} isTouchDevice={isTouchDevice} />
      </>
    );
  } else if ( year >= 2022 ) {
    content = (
      <DonateContent2022
        forDonor={forDonor}
        forMonthlyDonor={forMonthlyDonor}
        year={year}
        isTouchDevice={isTouchDevice}
        site={site}
        sites={sites}
        defaultSiteId={defaultSiteId}
      />
    );
  } else {
    content = (
      <>
        <StoreContent isTouchDevice={isTouchDevice} />
        <DonateContent year={year} data={data} isTouchDevice={isTouchDevice} />
      </>
    );
  }

  return (
    <div className="Donate">
      { content }
    </div>
  );
};

Donate.propTypes = {
  data: PropTypes.object,
  forDonor: PropTypes.bool,
  forMonthlyDonor: PropTypes.bool,
  site: PropTypes.object,
  sites: PropTypes.array,
  year: PropTypes.number,
  defaultSiteId: PropTypes.number
};

export default Donate;
