// Transparent PNGs from the supplied original logos. REDX X is red as requested.
export const courierPresets=Object.freeze([
 {id:'steadfast',name:'Steadfast',color:'#00a88c',logo:'assets/courier-steadfast-transparent.png'},
 {id:'pathao',name:'Pathao',color:'#ef3035',logo:'assets/courier-pathao-transparent.png'},
 {id:'carrybee',name:'CarryBee',color:'#ffca05',logo:'assets/courier-carrybee-transparent.png'},
 {id:'redx',name:'REDX',color:'#ed1b24',logo:'assets/courier-redx-transparent.png'}
]);
export function courierPreset(value){const id=String(value||'').toLowerCase().replace(/[\s_-]/g,'');return courierPresets.find(p=>p.id===id)}
export function methodCourierType(method={}){return method.provider==='custom'||method.provider==='manual'?method.provider_options?.courier_type||method.courier_type||method.name:method.provider||method.id||method.name}
