import {createSteadfastService,sameSecret} from '../server/steadfast-service.mjs';
export function createHandler(options={}){return async(req,res)=>{
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');
 if(req.method!=='POST')return res.status(405).json({error:'POST only.'});
 const env=options.env||process.env,secret=env.JIOFLOW_POLL_SECRET;
 if(!secret||secret.length<32||!sameSecret(String(req.headers.authorization||''),'Bearer '+secret))return res.status(401).json({error:'Unauthorized.'});
 try{return res.status(200).json(await createSteadfastService(options).poll())}catch{return res.status(503).json({error:'Courier polling unavailable. Check server configuration and database update 025.'})}
}}
export default createHandler();
