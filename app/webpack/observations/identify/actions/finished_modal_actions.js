const SHOW_FINISHED_MODAL = "show_finished_modal";
const HIDE_FINISHED_MODAL = "hide_finished_modal";

function showFinishedModal( ) { return { type: SHOW_FINISHED_MODAL }; }
function hideFinishedModal( ) { return { type: HIDE_FINISHED_MODAL }; }

export {
  SHOW_FINISHED_MODAL,
  HIDE_FINISHED_MODAL,
  showFinishedModal,
  hideFinishedModal
};
