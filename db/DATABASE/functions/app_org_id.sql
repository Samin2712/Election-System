CREATE OR REPLACE FUNCTION public.app_org_id()
 RETURNS bigint
 LANGUAGE sql
AS $function$
  SELECT NULLIF(current_setting('app.organization_id', true), '')::bigint;
$function$
;
