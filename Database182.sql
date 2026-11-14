begin;
-- Stop future negative-response alerts without changing follow-up data/history.
create or replace function jioflow_private.negative_followup_notice()
returns trigger language plpgsql security definer set search_path='' as $$begin return new;end$$;
revoke all on function jioflow_private.negative_followup_notice() from public,anon,authenticated;
-- Keep the installed visibility, scope, dismissals and unread rules.
do $patch$
declare d text;begin
 d:=pg_get_functiondef('public.jf_notifications_feed(uuid)'::regprocedure);
 if position('/*negative182*/' in d)=0 then
 if position('from public.jf_notifications n where' in d)=0 then raise exception 'Notification feed target missing.';end if;
 d:=replace(d,'from public.jf_notifications n where', 'from public.jf_notifications n where /*negative182*/ n.kind<>''negative_followup'' and');execute d;
 end if;
end $patch$;
commit;
