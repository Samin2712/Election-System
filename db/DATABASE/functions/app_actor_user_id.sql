CREATE OR REPLACE FUNCTION public.app_actor_user_id()
 RETURNS bigint
 LANGUAGE sql
AS $function$
  SELECT NULLIF(current_setting('app.actor_user_id', true), '')::bigint;
$function$
;
