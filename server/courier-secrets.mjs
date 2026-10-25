import {randomBytes,createCipheriv,createDecipheriv,hkdfSync} from 'node:crypto';
import {RequestError} from './account-service.mjs';
function key(env){const root=env.JIOFLOW_COURIER_ENCRYPTION_KEY||env.SUPABASE_SECRET_KEY||env.SUPABASE_SERVICE_ROLE_KEY;if(!root)throw new RequestError('Courier secret storage is not configured.',503);return hkdfSync('sha256',root,'JioFlow courier storage','delivery-method-credentials-v1',32)}
export function sealKeys(env,shop,id,values){
 const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',key(env),iv);cipher.setAAD(Buffer.from(shop+':'+id));const data=Buffer.concat([cipher.update(JSON.stringify(values),'utf8'),cipher.final()]);
 return ['v1',iv.toString('base64url'),cipher.getAuthTag().toString('base64url'),data.toString('base64url')].join('.');
}
export function openKeys(env,shop,id,sealed){
 try{const [version,iv,tag,data,...extra]=sealed.split('.');if(version!=='v1'||extra.length)throw Error();const decipher=createDecipheriv('aes-256-gcm',key(env),Buffer.from(iv,'base64url'));decipher.setAAD(Buffer.from(shop+':'+id));decipher.setAuthTag(Buffer.from(tag,'base64url'));const value=JSON.parse(Buffer.concat([decipher.update(Buffer.from(data,'base64url')),decipher.final()]).toString('utf8'));if(!value.api_key||!value.secret_key)throw Error();return value}catch{throw new RequestError('Saved courier keys need to be entered again by an administrator.',503)}
}
