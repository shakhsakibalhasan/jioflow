begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='039_pathao') then raise exception 'Apply Database57.sql first.';end if;end$$;
alter table public.jf_courier_methods add column logo_path text not null default '',add column brand_color text not null default '#00a88c',add column auth_email text not null default '',add column history_enabled boolean not null default true;
alter table public.jf_courier_methods add constraint jf_courier_brand_color check(brand_color ~ '^#[a-fA-F0-9]{6}$');
alter function public.jf_delivery_method_save(uuid,uuid,jsonb,text) rename to jf_delivery_method_save_before_branding;
revoke all on function public.jf_delivery_method_save_before_branding(uuid,uuid,jsonb,text) from public,anon,authenticated;
create function public.jf_delivery_method_save(target_shop uuid,method_id uuid,details jsonb,encrypted_keys text default null) returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid;logo text;color text;mail text;
begin
 if details?'logo_path' then logo:=details->>'logo_path';if logo is null or length(logo)>360000 or logo<>'' and logo !~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$' then raise exception 'Upload a PNG, JPEG or WebP courier logo under 250 KB.';end if;end if;
 if details?'brand_color' then color:=details->>'brand_color';if color is null or color !~ '^#[a-fA-F0-9]{6}$' then raise exception 'Choose a valid courier brand color.';end if;end if;
 if details?'history_enabled' and jsonb_typeof(details->'history_enabled') is distinct from 'boolean' then raise exception 'Check history switch.';end if;
 if details?'auth_email' then mail:=details->>'auth_email';if mail is null or length(mail)>254 then raise exception 'Check merchant email.';end if;end if;
 rid:=public.jf_delivery_method_save_before_branding(target_shop,method_id,details-'logo_path'-'brand_color'-'auth_email'-'history_enabled',encrypted_keys);
 update public.jf_courier_methods set logo_path=coalesce(logo,logo_path),brand_color=coalesce(color,brand_color),auth_email=coalesce(mail,auth_email),history_enabled=coalesce((details->>'history_enabled')::boolean,history_enabled) where shop_id=target_shop and id=rid;
 return rid;
end$$;
create or replace function public.jf_delivery_methods(target_shop uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a jsonb;result jsonb;
begin
 a:=public.jf_courier_access(target_shop,null);if jioflow_private.agent_member(target_shop) is not null then a:=a||jsonb_build_object('can_configure',false);end if;
 select coalesce(jsonb_agg((to_jsonb(m)-'sealed')-case when a->>'can_configure'='true' then '__none__' else 'auth_email' end order by preferred desc,name),'[]') into result from public.jf_courier_methods m where shop_id=target_shop and deleted_at is null and (a->>'can_configure'='true' or active);
 return jsonb_build_object('can_configure',a->'can_configure','methods',result,'has_methods',exists(select 1 from public.jf_courier_methods where shop_id=target_shop));
end$$;
revoke all on function public.jf_delivery_method_save(uuid,uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.jf_delivery_method_save(uuid,uuid,jsonb,text) to authenticated;
insert into public.jf_schema_versions(version) values('040_courier_branding') on conflict do nothing;
commit;
