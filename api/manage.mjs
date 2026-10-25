import {createAccountService,RequestError} from '../server/account-service.mjs';
export function createHandler(options={}){return async function handler(req,res){
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');
 if(req.method!=='POST'){res.setHeader('Allow','POST');return res.status(405).json({error:'Method not allowed.'})}
 try{
  const service=createAccountService(options);
  if(req.headers.origin!==service.origin)throw new RequestError('This request origin is not allowed.',403);
  if(!String(req.headers['content-type']||'').startsWith('application/json'))throw new RequestError('Use a JSON request.',415);
  const raw=req.body;if(typeof raw==='string'&&Buffer.byteLength(raw)>8192)throw new RequestError('Request too large.',413);
  let input;try{input=typeof raw==='string'?JSON.parse(raw):raw}catch{throw new RequestError('Invalid JSON.')}
  if(!input||typeof input!=='object'||Array.isArray(input)||Buffer.byteLength(JSON.stringify(input))>8192)throw new RequestError('Invalid request.');
  const header=String(req.headers.authorization||'');if(!header.startsWith('Bearer '))throw new RequestError('Please sign in.',401);
  const result=await service.execute(header.slice(7),input);return res.status(200).json(result);
 }catch(error){const known=error instanceof RequestError;return res.status(known?error.status:503).json({error:known?error.message:'The account service is temporarily unavailable. Please try again.'})}
}}
export default createHandler();
