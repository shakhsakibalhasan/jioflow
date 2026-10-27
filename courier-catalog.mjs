// Shared connection catalog. Only installed adapters may claim live capabilities.
export const courierCatalog=Object.freeze([
 {id:'steadfast',name:'Steadfast',adapter:'steadfast',fields:[['api_key','API Key'],['secret_key','Secret Key']],booking:true,tracking:true,history:true},
 {id:'pathao',name:'Pathao',adapter:'pathao',fields:[['api_key','Client ID'],['secret_key','Client Secret'],['username','Merchant email'],['password','Merchant password']],booking:true,tracking:true,history:true},
 {id:'carrybee',name:'CarryBee',adapter:null,fields:[['api_key','Client ID'],['secret_key','Client Secret'],['client_context','Client Context']],booking:false,tracking:false,history:false},
 {id:'redx',name:'REDX',adapter:null,fields:[['access_token','API Access Token']],booking:false,tracking:false,history:false},
 {id:'paperfly',name:'Paperfly',adapter:null,fields:[['username','Merchant username'],['password','Merchant password'],['api_key','API Key']],booking:false,tracking:false,history:false},
 {id:'ecourier',name:'eCourier',adapter:'ecourier',fields:[['api_key','API Key'],['secret_key','API Secret'],['user_id','User ID']],booking:true,tracking:true,history:true},
 {id:'sundarban',name:'Sundarban',adapter:null,fields:[['api_key','API Key'],['secret_key','API Secret'],['access_token','Access Token']],booking:false,tracking:false,history:false},
 {id:'other',name:'Other courier',adapter:null,fields:[['api_key','API Key'],['secret_key','API Secret'],['access_token','Access Token'],['username','Merchant username'],['password','Merchant password'],['client_context','Client Context'],['user_id','User ID']],booking:true,tracking:true,history:true}
]);
export function courierDefinition(value){const id=String(value||'').trim().toLowerCase().replace(/[\s_-]/g,'');return courierCatalog.find(c=>c.id===id)||courierCatalog.at(-1)}
export function courierCapabilities(method){const definition=courierDefinition(method.provider==='custom'?method.provider_options?.courier_type:method.provider),verified=method.active&&method.check_status==='verified'&&!!definition.adapter;return {adapter_installed:!!definition.adapter,connection:definition.adapter?(verified?'verified':'not_verified'):'setup_required',booking:!!(verified&&definition.booking&&method.booking_enabled),tracking:!!(verified&&definition.tracking),history:!!(verified&&definition.history&&method.history_enabled!==false)}}
