CREATE OR REPLACE FUNCTION public.sp_process_scheduled_elections()
 RETURNS TABLE(action text, election_id bigint, election_name character varying)
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Open elections that should start
  UPDATE elections e
  SET status = 'OPEN'
  WHERE status = 'SCHEDULED'
    AND start_datetime <= NOW()
    AND start_datetime IS NOT NULL
  RETURNING 'OPENED' as action, e.election_id, e.election_name
  INTO action, election_id, election_name;

  IF FOUND THEN
    RETURN NEXT;
  END IF;

  -- Close elections that should end
  UPDATE elections e
  SET status = 'CLOSED'
  WHERE status = 'OPEN'
    AND end_datetime <= NOW()
    AND end_datetime IS NOT NULL
  RETURNING 'CLOSED' as action, e.election_id, e.election_name
  INTO action, election_id, election_name;

  IF FOUND THEN
    RETURN NEXT;
  END IF;

  RETURN;
END;
$function$
;
