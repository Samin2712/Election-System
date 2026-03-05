CREATE OR REPLACE FUNCTION public.sp_get_my_org_requests(p_user_id bigint)
 RETURNS TABLE(request_id bigint, organization_name character varying, organization_type character varying, organization_code character varying, purpose text, expected_members integer, proof_document_url text, status org_request_status, admin_notes text, reviewed_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
  my_cursor CURSOR FOR
    SELECT
      r.request_id,
      r.organization_name,
      r.organization_type,
      r.organization_code,
      r.purpose,
      r.expected_members,
      r.proof_document_url,
      r.status,
      r.admin_notes,
      r.reviewed_at,
      r.created_at
    FROM organization_requests r
    WHERE r.requested_by = p_user_id
    ORDER BY r.created_at DESC;
  rec RECORD;
BEGIN
  OPEN my_cursor;
  LOOP
    FETCH my_cursor INTO rec;
    EXIT WHEN NOT FOUND;

    request_id        := rec.request_id;
    organization_name := rec.organization_name;
    organization_type := rec.organization_type;
    organization_code := rec.organization_code;
    purpose           := rec.purpose;
    expected_members  := rec.expected_members;
    proof_document_url := rec.proof_document_url;
    status            := rec.status;
    admin_notes       := rec.admin_notes;
    reviewed_at       := rec.reviewed_at;
    created_at        := rec.created_at;

    RETURN NEXT;
  END LOOP;
  CLOSE my_cursor;
END;
$function$
;
