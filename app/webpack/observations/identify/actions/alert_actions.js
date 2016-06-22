const SHOW_ALERT = "show_alert";
const HIDE_ALERT = "hide_alert";

function showAlert( content, options = {} ) { return { type: SHOW_ALERT, content, options }; }
function hideAlert( ) { return { type: HIDE_ALERT }; }

export {
  SHOW_ALERT,
  HIDE_ALERT,
  showAlert,
  hideAlert
};
