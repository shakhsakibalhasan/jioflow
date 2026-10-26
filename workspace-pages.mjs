const stacks=new WeakMap();
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
// Forms use the existing guarded save callbacks, but render as normal workspace pages.
export function openWorkspacePage({view,title,body,submit,label='Save changes',keepOpen=false}){
 const doc=view.ownerDocument,stack=(stacks.get(view)||[]).filter(p=>p.isConnected);for(const p of stack)p.id='workspace-parent-'+stack.indexOf(p);
 const page=doc.createElement('dialog');page.id='online-dialog';page.className='online-dialog workspace-action-page';page.setAttribute('open','');page.innerHTML=`<header class="online-dialog-header workspace-page-header"><button type="button" class="online-dialog-close workspace-back" aria-label="Back">← Back</button><div><small>Workspace</small><h2>${esc(title)}</h2></div></header><form>${body}<p class="online-message" role="alert"></p><div class="online-dialog-actions"><button type="button" class="online-dialog-close">Cancel</button><button type="submit" class="${title==='Delete shop'?'danger':'primary'}">${esc(label)}</button></div></form>`;
 for(const child of [...view.children])child.classList.add('workspace-page-is-covered');view.append(page);stack.push(page);stacks.set(view,stack);
 if(typeof page.close!=='function')page.close=()=>{page.removeAttribute('open');page.dispatchEvent(new doc.defaultView.Event('close'))};
 page.querySelectorAll('.online-dialog-close').forEach(button=>button.onclick=()=>page.close());
 page.addEventListener('close',()=>{page.remove();const remaining=(stacks.get(view)||[]).filter(p=>p.isConnected&&p!==page);stacks.set(view,remaining);const active=remaining.at(-1);if(active){active.id='online-dialog';active.classList.remove('workspace-page-is-covered')}else for(const child of [...view.children])child.classList.remove('workspace-page-is-covered')});
 page.querySelector('form').onsubmit=async event=>{event.preventDefault();const form=event.target,button=form.querySelector('[type=submit]'),message=form.querySelector('[role=alert]');if(button.disabled||button.hidden)return;button.disabled=true;message.textContent='';try{await submit(new FormData(form));if(!keepOpen)page.close()}catch(error){message.textContent=error.message}finally{button.disabled=false}};
 doc.defaultView?.scrollTo?.(0,0);return page;
}
