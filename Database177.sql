begin;
-- User-confirmed baseline: legacy uploaded rows with no assignment evidence
-- start in Never Assigned. Never clear any recorded assignment history.
lock table public.jf_customers in share row exclusive mode;
drop trigger if exists jf_assignment_flags171 on public.jf_customers;
update public.jf_customers c
set assignment_known171=true,
    ever_assigned171=c.ever_assigned171
      or c.assigned_membership_id is not null
      or nullif(trim(c.unassignment_tag),'') is not null
      or exists(select 1 from jioflow_private.jf_assignment_history168 h
                where h.shop_id=c.shop_id and h.customer_id=c.id and h.membership_id is not null)
where not c.assignment_known171
   or (not c.ever_assigned171 and (
       c.assigned_membership_id is not null
       or nullif(trim(c.unassignment_tag),'') is not null
       or exists(select 1 from jioflow_private.jf_assignment_history168 h
                 where h.shop_id=c.shop_id and h.customer_id=c.id and h.membership_id is not null)));
create trigger jf_assignment_flags171 before insert or update on public.jf_customers
for each row execute function jioflow_private.jf_assignment_flags171();
commit;
