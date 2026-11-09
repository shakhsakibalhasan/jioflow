const watched132=new WeakSet();
// Remove cancellation navigation/actions, retaining saved history and dismiss buttons.
export function removeCancelledUi132(root){
 const Observer=root.ownerDocument?.defaultView?.MutationObserver;if(Observer&&!watched132.has(root)){watched132.add(root);new Observer(changes=>{if(changes.some(c=>c.addedNodes.length))removeCancelledUi132(root)}).observe(root,{childList:true,subtree:true})}
 root.querySelectorAll('.metric-tile,.insight-tile,.overview-tile').forEach(el=>{const label=el.querySelector('.label,.tile-label')?.textContent.trim()||'';if(/^cancelled(?: orders| customers| follow-ups)?$/i.test(label))el.remove()});
 root.querySelectorAll('[data-original-tab]').forEach(el=>{if(/^cancelled?$/i.test(el.dataset.originalTab||''))el.remove()});
 root.querySelectorAll('select option').forEach(el=>{if(/^cancelled?$/i.test(el.value||el.textContent.trim()))el.remove()});
 root.querySelectorAll('[data-order-cancel]').forEach(el=>el.remove());
}
