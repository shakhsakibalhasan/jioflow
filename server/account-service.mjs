// Server-only module. Never copy this directory into the static build.
export class RequestError extends Error { constructor(message,status=400){super(message);this.status=status;} }
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function configuration(env){
 const url=env.SUPABASE_URL,publicKey=env.SUPABASE_PUBLISHABLE_KEY,secret=env.SUPABASE_SECRET_KEY||env.SUPABASE_SERVICE_ROLE_KEY,origin=env.JIOFLOW_APP_ORIGIN;
 if(!url||!publicKey||!secret||!origin)throw new RequestError('Account service setup is incomplete. Contact your administrator.',503);
 if(new URL(url).protocol!=='https:'||new URL(origin).protocol!=='https:'||new URL(origin).origin!==origin)throw new RequestError('Account service configuration is invalid.',503);
 if(secret.startsWith('sb_publishable_')||secret===publicKey)throw new RequestError('The account service requires a server credential.',503);
 return {url:url.replace(/\/$/,''),publicKey,secret,origin};
}
export function createAccountService({env=process.env,fetcher=fetch}={}){
 const c=configuration(env);
 async function call(path,{method='GET',body,token,key=c.publicKey}={}){
  const response=await fetcher(c.url+path,{method,headers:{apikey:key,'Content-Type':'application/json',...(token&&!token.startsWith('sb_secret_')?{Authorization:'Bearer '+token}:{})},signal:AbortSignal.timeout(15000),...(body?{body:JSON.stringify(body)}:{})});
  const data=await response.json().catch(()=>null);
  if(!response.ok){
   const code=data?.code||data?.error_code;
   const status=response.status===401?401:code==='42501'?403:code==='23505'?409:response.status===429?429:400;
   const safe=code==='weak_password'?'Password does not meet the hosted Auth requirements. Ask the Creator to check the minimum password length in Supabase Auth settings.':code==='PGRST202'?'Database update 008 is required for account email controls.':code==='over_email_send_rate_limit'||code==='over_request_rate_limit'?'Wait at least one minute before sending another email.':code==='42501'?'Your role does not permit this action.':code==='23505'?(/email/i.test(data?.message||'')?'This email already belongs to an account. Use Find account in Account Access.':/Owner/i.test(data?.message||'')?'This shop already has an Owner. Edit the existing Owner assignment.':'An existing account or Owner assignment conflicts. Use Find account to check.'):code==='P0001'?'Please wait a minute before sending more invitations.':code==='email_exists'||code==='email_address_not_authorized'?'The email invitation could not be sent. Check the address and email delivery configuration.':response.status===429?'Too many requests. Please try again shortly.':path.startsWith('/rest/v1/rpc/')?'Account setup could not be completed. Check migration 003 and your permissions.':'The account request failed. Please check email delivery and try again.';
   throw new RequestError(safe,status);
  }
  return data;
 }
 async function execute(token,input){
  if(typeof token!=='string'||token.length<10||token.length>10000)throw new RequestError('Please sign in.',401);
  const user=await call('/auth/v1/user',{token});
  if(!user?.id||!user.email_confirmed_at)throw new RequestError('Verify your email before managing accounts.',403);
  // Never trust role, user id or Creator status supplied by the browser.
  const p=await call('/rest/v1/jf_profiles?select=id,active,deleted_at&id=eq.'+encodeURIComponent(user.id)+'&limit=1',{token});
  if(!p?.[0]?.active||p[0].deleted_at)throw new RequestError('Your account is inactive.',403);
  const rpc=(name,body)=>call('/rest/v1/rpc/'+name,{method:'POST',token,body});
  if(input?.action==='agent_reset_send'){
   if(!uuid.test(input.request_id||''))throw new RequestError('Select a password reset request.');
   const target=await rpc('jf_authorize_agent_reset',{request_id:input.request_id});
   if(!target?.email)throw new RequestError('Agent account was not found.',404);
   await call('/auth/v1/recover?redirect_to='+encodeURIComponent(c.origin+'/'),{method:'POST',body:{email:target.email}});
   return {message:'Reset email requested for the approved Agent. The Agent must finish resetting within one hour of approval.'};
  }
  if(['account_reset','account_resend','account_email_change'].includes(input?.action)){
   if(!uuid.test(input.user_id||''))throw new RequestError('Select an account.');
   if(input.action==='account_reset'&&(await rpc('jf_is_agent_account',{target_user:input.user_id}))===true)throw new RequestError('Agent password reset requires approval in Notifications.',403);
   const target=await rpc('jf_account_email_target',{target_user:input.user_id});
   if(!target?.email)throw new RequestError('The target account was not found.',404);
   if(input.action==='account_email_change'){
    const next=String(input.email||'').trim().toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(next)||next.length>254)throw new RequestError('Enter a valid new email.');
    if(next===target.email.toLowerCase())return {message:'This email is already in use for this account.'};
    // Prepare the provider-managed change, never return its tokens or links.
    // Resend is a separate action after the provider frequency limit expires.
    await call('/auth/v1/admin/generate_link',{method:'POST',key:c.secret,token:c.secret,body:{type:'email_change_new',email:target.email,new_email:next,redirect_to:c.origin+'/'}});
    return {message:'Email change prepared. Wait at least one minute, then click Send verification. Keep using the current email until the change is confirmed.'};
   }
   if(!target.verified){
    const invitedAgain=await call('/auth/v1/invite?redirect_to='+encodeURIComponent(c.origin+'/'),{method:'POST',key:c.secret,token:c.secret,body:{email:target.email}});
    if((invitedAgain?.id||invitedAgain?.user?.id)!==input.user_id)throw new RequestError('Verification identity could not be confirmed.',502);
    return {message:'Verification / account setup email requested. Check this account inbox and spam folder.'};
   }
   if(input.action==='account_resend'){
    if(!target.pending_email)return {message:'This email is already verified.'};
    await call('/auth/v1/resend?redirect_to='+encodeURIComponent(c.origin+'/'),{method:'POST',body:{type:'email_change',email:target.email}});
    return {message:'Email change confirmation requested. Check the new and current inboxes; both confirmations may be required.'};
   }
   await call('/auth/v1/recover?redirect_to='+encodeURIComponent(c.origin+'/'),{method:'POST',body:{email:target.email}});
   return {message:'Password reset requested for the account email. Check inbox and spam. Delivery depends on the email service.'};
  }
  if(input?.action==='create_shop'){
   const name=String(input.name||'').trim();if(!name||name.length>120)throw new RequestError('Enter a shop name (up to 120 characters).');
   const id=await rpc('jf_create_shop',{shop_name:name,contact_email:String(input.email||''),contact_phone:String(input.phone||''),shop_address:String(input.address||''),shop_website:String(input.website||'')});
   return {shop_id:id,message:'Shop created. You can now assign its Owner.'};
  }
  if(input?.action!=='invite_account')throw new RequestError('Unsupported account action.');
  if(!uuid.test(input.shop_id||'')||!['owner','admin','agent'].includes(input.role))throw new RequestError('Choose a shop and account role.');
  const email=String(input.email||'').trim().toLowerCase(),name=String(input.name||'').trim();
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>254||!name||name.length>120)throw new RequestError('Enter a valid name and email.');
  const password=input.password||'';
  if(typeof password!=='string'||password&&(password.length<6||password.length>128))throw new RequestError('Initial passwords must contain 6–128 characters.');
  const rid=await rpc('jf_prepare_invitation',{target_shop:input.shop_id,desired_role:input.role,person_name:name,person_email:email,person_phone:String(input.phone||'')});
  if(input.role==='agent'){
   const jio=String(input.jio_id||'').trim();
   if(!/^[A-Za-z0-9_-]{3,50}$/.test(jio)||!password)throw new RequestError('Enter a unique Jio ID (3–50 letters, numbers, _ or -) and a password of at least 6 characters.');
   await rpc('jf_validate_agent_id',{jio_id:jio});
   // Agents are managed identities. No invitation or verification email is sent.
   // Database flag prevents treating this provider confirmation as verified mail.
   const created=await call('/auth/v1/admin/users',{method:'POST',key:c.secret,token:c.secret,body:{email,password,email_confirm:true,app_metadata:{jioflow_managed_agent:true},user_metadata:{full_name:name}}});
   const id=created?.id||created?.user?.id;if(!uuid.test(id||''))throw new RequestError('Agent identity could not be created.',502);
   try{await rpc('jf_finish_agent',{request_id:rid,agent_user:id,jio_id:jio})}catch(error){try{await call('/auth/v1/admin/users/'+id,{method:'DELETE',key:c.secret,token:c.secret})}catch{}throw error}
   return {user_id:id,message:'Agent created. Every new login requires approval from an Admin, Owner or Creator.'};
  }
  // Auth delivers verification mail. Role assignment uses database records only.
  const invited=await call('/auth/v1/invite?redirect_to='+encodeURIComponent(c.origin+'/'),{method:'POST',key:c.secret,token:c.secret,body:{email,data:{full_name:name}}});
  const id=invited?.id||invited?.user?.id;if(!uuid.test(id||''))throw new RequestError('Invitation delivery could not be confirmed.',502);
  await rpc('jf_finish_invitation',{request_id:rid,invited_user:id});
  let warning='';
  if(password){try{await call('/auth/v1/admin/users/'+id,{method:'PUT',key:c.secret,token:c.secret,body:{password}})}catch{warning='The account was invited, but the initial password was not saved. The recipient can set a password through the email link.'}}
  return {user_id:id,message:input.role==='agent'?'Invitation sent. Agent workspace access remains pending approval and device setup.':'Invitation sent. The recipient must verify their email.',...(warning?{warning}:{})};
 }
 return {execute,origin:c.origin};
}
