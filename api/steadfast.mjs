import {createSteadfastService} from '../server/steadfast-service.mjs';
import {RequestError} from '../server/account-service.mjs';
export function createHandler(options={}){return async(req,res)=>{
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');
 if(req.method!=='POST'){res.setHeader('Allow','POST');return res.status(405).json({error:'POST only.'})}
 try{
  const service=createSteadfastService(options);
  if(req.headers.origin!==service.origin)throw new RequestError('Request origin denied.',403);
  if(!String(req.headers['content-type']||'').startsWith('application/json'))throw new RequestError('Use a JSON request.',415);
  const raw=req.body;if(Buffer.byteLength(typeof raw==='string'?raw:JSON.stringify(raw||{}))>400000)throw new RequestError('Request too large.',413);
  let input;try{input=typeof raw==='string'?JSON.parse(raw):raw}catch{throw new RequestError('Invalid JSON.')}
  if(!input||typeof input!=='object'||Array.isArray(input))throw new RequestError('Invalid request.');
  const auth=String(req.headers.authorization||'');if(!auth.startsWith('Bearer ')||auth.length>10007)throw new RequestError('Please sign in.',401);
  return res.status(200).json(await service.execute(auth.slice(7),input));
 }catch(e){return res.status(e instanceof RequestError?e.status:503).json({error:e instanceof RequestError?e.message:'Courier service unavailable. The last saved status was kept.'})}
}}
export default createHandler();
