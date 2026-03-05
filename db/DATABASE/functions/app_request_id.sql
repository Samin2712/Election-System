CREATE OR REPLACE FUNCTION public.app_request_id()
 RETURNS text
 LANGUAGE sql
AS $function$
  SELECT NULLIF(current_setting('app.request_id', true), '');
$function$
;
