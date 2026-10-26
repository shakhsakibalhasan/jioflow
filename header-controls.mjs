// Move existing controls, preserving their values and bound event handlers.
export function placeHeaderControls(root,controls){
 const actions=root.closest('main')?.querySelector('.heading>.row');if(!actions||!controls)return false;
 actions.querySelector('[data-header-report-controls]')?.remove();
 if(actions.querySelector('[data-section="new"]'))controls.querySelectorAll('[data-original-nav="new"]').forEach(button=>button.remove());
 controls.dataset.headerReportControls='';controls.classList.add('header-report-controls');
 const newOrder=actions.querySelector('[data-section="new"]');if(newOrder)newOrder.before(controls);else actions.prepend(controls);return true;
}
