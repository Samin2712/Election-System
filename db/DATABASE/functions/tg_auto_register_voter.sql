CREATE OR REPLACE FUNCTION public.tg_auto_register_voter()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_user_id BIGINT;
    v_username VARCHAR(100);
    v_email CITEXT;
    v_org_id BIGINT;
    v_role_name VARCHAR(50);
BEGIN
    -- Only active members
    IF NEW.is_active = FALSE THEN
        RETURN NEW;
    END IF;

    v_user_id := NEW.user_id;
    v_org_id := NEW.organization_id;
    v_role_name := NEW.role_name;

    -- EXCLUDE OWNER/ADMIN from being voters
    IF v_role_name IN ('OWNER', 'ADMIN') THEN
        RETURN NEW;
    END IF;

    -- Get user details
    SELECT username, email INTO v_username, v_email
    FROM user_accounts
    WHERE user_id = v_user_id;

    -- 1. Insert into Master (Idempotent)
    INSERT INTO org_member_master (organization_id, member_id, member_type, full_name, email)
    VALUES (v_org_id, v_user_id::VARCHAR, 'USER', v_username, v_email)
    ON CONFLICT (organization_id, member_id) 
    DO UPDATE SET 
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email;

    -- 2. Register as Voter (Approved)
    INSERT INTO voters (
        organization_id, user_id, member_id, voter_type, status, is_approved, approved_at
    )
    VALUES (
        v_org_id, v_user_id, v_user_id::VARCHAR, 'USER', 'APPROVED', TRUE, NOW()
    )
    ON CONFLICT (organization_id, user_id)
    DO UPDATE SET
        status = 'APPROVED',
        is_approved = TRUE,
        approved_at = NOW()
    WHERE voters.status != 'APPROVED';

    RETURN NEW;
END;
$function$
;
