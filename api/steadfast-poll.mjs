import {createSteadfastService,sameSecret} from '../server/steadfast-service.mjs';
// Courier status polling. Called by Vercel Cron (GET, "Authorization: Bearer <CRON_SECRET>")
// or manually (POST, "Authorization: Bearer <JIOFLOW_POLL_SECRET>"). Either secret must be 32+ characters.
export function createHandler(options={}){return async(req,res)=>{
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');
 if(req.method!=='POST'&&req.method!=='GET')return res.status(405).json({error:'GET or POST only.'});
 const env=options.env||process.env,auth=String(req.headers.authorization||'');
 const allowed=[env.JIOFLOW_POLL_SECRET,env.CRON_SECRET].filter(secret=>typeof secret==='string'&&secret.length>=32);
 if(!allowed.some(secret=>sameSecret(auth,'Bearer '+secret)))return res.status(401).json({error:'Unauthorized.'});
 try{return res.status(200).json(await createSteadfastService(options).poll())}catch{return res.status(503).json({error:'Courier polling unavailable. Check server configuration and database update 025.'})}
}}
export default createHandler();
