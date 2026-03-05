CREATE OR REPLACE FUNCTION public.sp_get_org_requests(p_status org_request_status DEFAULT NULL::org_request_status)
 RETURNS TABLE(request_id bigint, requested_by bigint, requester_username character varying, requester_email citext, organization_name character varying, organization_type character varying, organization_code character varying, purpose text, expected_members integer, proof_document_url text, status org_request_status, admin_notes text, reviewed_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
  req_cursor CURSOR FOR
    SELECT
      r.request_id,
      r.requested_by,
      u.username AS requester_username,
      u.email AS requester_email,
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
    JOIN user_accounts u ON r.requested_by = u.user_id
    WHERE (p_status IS NULL OR r.status = p_status)
    ORDER BY
      CASE r.status
        WHEN 'PENDING' THEN 0
        WHEN 'APPROVED' THEN 1
        WHEN 'REJECTED' THEN 2
      END,
      r.created_at DESC;
  rec RECORD;
BEGIN
  OPEN req_cursor;
  LOOP
    FETCH req_cursor INTO rec;
    EXIT WHEN NOT FOUND;

    request_id        := rec.request_id;
    requested_by      := rec.requested_by;
    requester_username := rec.requester_username;
    requester_email   := rec.requester_email;
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
  CLOSE req_cursor;
END;
$function$
;
