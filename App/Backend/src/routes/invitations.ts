import { Router, Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import multer from 'multer';
import { parse } from 'csv-parse/sync';
import { pool } from '../db';
import { authMiddleware, optionalAuthMiddleware } from '../middleware/auth';
import { withTx } from '../tx';
import { emailService } from '../services/emailService';
import bcrypt from 'bcryptjs';
import { signAccessToken, signRefreshToken } from '../utils/jwt';

const router = Router();

// Configure multer for CSV upload
const storage = multer.memoryStorage();
const upload = multer({
    storage,
    limits: {
        fileSize: 5 * 1024 * 1024, // 5MB limit
    },
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'text/csv' || 
            file.originalname.endsWith('.csv') ||
            file.mimetype === 'application/vnd.ms-excel') {
            cb(null, true);
        } else {
            cb(new Error('Only CSV files are allowed'));
        }
    },
});

function parseIntParam(value: string | string[] | undefined, name: string): number {
    const strVal = Array.isArray(value) ? value[0] : value;
    const n = Number(strVal);
    if (!Number.isInteger(n) || n <= 0) {
        const err: any = new Error(`Invalid ${name}`);
        err.status = 400;
        throw err;
    }
    return n;
}

// ============================================
// CSV BULK UPLOAD
// ============================================

// POST /invitations/bulk-upload/:orgId - Upload CSV with emails
router.post('/bulk-upload/:orgId', authMiddleware, upload.single('csv'), async (req: Request, res: Response, next: NextFunction) => {
    try {
        const userId = req.user!.user_id;
        const orgId = parseIntParam(req.params.orgId, 'orgId');
        const roleName = (req.body.role_name || 'MEMBER').toUpperCase();
        const daysValid = parseInt(req.body.days_valid || '7');
        const sendEmails = req.body.send_emails !== 'false';

        if (!req.file) {
            return res.status(400).json({ ok: false, error: 'No CSV file uploaded' });
        }

        // Get organization details
        const { rows: orgRows } = await pool.query(
            'SELECT organization_name FROM organizations WHERE organization_id = $1',
            [orgId]
        );
        if (orgRows.length === 0) {
            return res.status(404).json({ ok: false, error: 'Organization not found' });
        }
        const organizationName = orgRows[0].organization_name;

        // Get user details for inviter name
        const { rows: userRows } = await pool.query(
            'SELECT username FROM user_accounts WHERE user_id = $1',
            [userId]
        );
        const inviterName = userRows[0]?.username || 'Admin';

        // Parse CSV
        const csvContent = req.file.buffer.toString('utf-8');
        let records: any[];
        
        try {
            records = parse(csvContent, {
                columns: true,
                skip_empty_lines: true,
                trim: true,
            });
        } catch (parseError: any) {
            return res.status(400).json({ 
                ok: false, 
                error: 'Invalid CSV format',
                details: parseError.message 
            });
        }

        // Validate CSV has email column
        if (records.length === 0) {
            return res.status(400).json({ ok: false, error: 'CSV file is empty' });
        }

        const firstRecord = records[0];
        const emailColumn = Object.keys(firstRecord).find(
            key => key.toLowerCase() === 'email'
        );

        if (!emailColumn) {
            return res.status(400).json({ 
                ok: false, 
                error: 'CSV must have an "email" column',
                foundColumns: Object.keys(firstRecord)
            });
        }

        // Extract and validate emails
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        const emails: string[] = [];
        const invalidEmails: string[] = [];

        for (const record of records) {
            const email = (record[emailColumn] || '').trim().toLowerCase();
            if (email && emailRegex.test(email)) {
                emails.push(email);
            } else if (email) {
                invalidEmails.push(email);
            }
        }

        if (emails.length === 0) {
            return res.status(400).json({ 
                ok: false, 
                error: 'No valid email addresses found in CSV',
                invalidEmails 
            });
        }

        // Create batch record
        const { rows: batchRows } = await pool.query(
            `INSERT INTO invitation_batches (organization_id, created_by, total_emails, status)
             VALUES ($1, $2, $3, 'PROCESSING')
             RETURNING batch_id`,
            [orgId, userId, emails.length]
        );
        const batchId = batchRows[0].batch_id;

        // Process invitations
        const results: Array<{
            email: string;
            status: string;
            message: string;
            invite_id?: number;
        }> = [];
        const tokenMap = new Map<string, string>();
        let successful = 0;
        let failed = 0;

        for (const email of emails) {
            const token = crypto.randomBytes(16).toString('hex');

            try {
                const { rows } = await pool.query(
                    `SELECT * FROM sp_create_bulk_invite($1, $2, $3, $4, $5, $6, $7)`,
                    [orgId, email, token, roleName, userId, batchId, daysValid]
                );

                const result = rows[0];
                if (result.status === 'SUCCESS') {
                    tokenMap.set(email, token);
                    successful++;
                    results.push({
                        email,
                        status: 'SUCCESS',
                        message: result.message,
                        invite_id: result.invite_id
                    });
                } else {
                    failed++;
                    results.push({
                        email,
                        status: result.status,
                        message: result.message
                    });
                }
            } catch (error: any) {
                failed++;
                results.push({
                    email,
                    status: 'ERROR',
                    message: error.message
                });
            }
        }

        // Send emails if requested
        let emailResults: any = null;
        if (sendEmails && tokenMap.size > 0) {
            const expiresAt = new Date();
            expiresAt.setDate(expiresAt.getDate() + daysValid);

            emailResults = await emailService.sendBulkInvitations(
                Array.from(tokenMap.keys()),
                organizationName,
                tokenMap,
                expiresAt,
                inviterName
            );

            // Update email_sent status for each invite
            for (const result of emailResults.results) {
                if (result.success) {
                    const token = tokenMap.get(result.email);
                    if (token) {
                        await pool.query(
                            `UPDATE organization_invites 
                             SET email_sent = TRUE, email_sent_at = CURRENT_TIMESTAMP 
                             WHERE token = $1`,
                            [token]
                        );
                    }
                }
            }
        }

        // Update batch status
        await pool.query(
            `UPDATE invitation_batches 
             SET successful_emails = $1, failed_emails = $2, status = 'COMPLETED', completed_at = CURRENT_TIMESTAMP
             WHERE batch_id = $3`,
            [successful, failed, batchId]
        );

        return res.json({
            ok: true,
            batch_id: batchId,
            summary: {
                total: emails.length,
                successful,
                failed,
                invalid_emails: invalidEmails.length,
                emails_sent: emailResults?.sent || 0,
                emails_failed: emailResults?.failed || 0
            },
            results,
            invalidEmails: invalidEmails.length > 0 ? invalidEmails : undefined
        });
    } catch (err: any) {
        if (err.message && err.message.includes('Only OWNERS')) {
            return res.status(403).json({ ok: false, error: err.message });
        }
        next(err);
    }
});

// ============================================
// TOKEN VALIDATION (PUBLIC - No Auth Required)
// ============================================

// GET /invitations/validate?token=xxx - Validate invite token
router.get('/validate', async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { token } = req.query;

        if (!token || typeof token !== 'string') {
            return res.status(400).json({ ok: false, error: 'Token is required' });
        }

        const { rows } = await pool.query(
            `SELECT * FROM sp_validate_invite_token($1)`,
            [token]
        );

        const result = rows[0];

        if (!result.valid) {
            return res.status(400).json({
                ok: false,
                error: 'Invalid or expired invitation token',
                expired: result.expires_at ? new Date(result.expires_at) < new Date() : false
            });
        }

        return res.json({
            ok: true,
            valid: true,
            email: result.email,
            organization: {
                id: result.organization_id,
                name: result.organization_name
            },
            role: result.role_name,
            expires_at: result.expires_at,
            user_exists: result.user_exists,
            user_id: result.user_id
        });
    } catch (err) {
        next(err);
    }
});

// ============================================
// ACCEPT INVITATION (Logged-in User)
// ============================================

// POST /invitations/accept - Accept invitation (logged-in user)
router.post('/accept', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const userId = req.user!.user_id;
        const { token } = req.body;

        if (!token) {
            return res.status(400).json({ ok: false, error: 'Token is required' });
        }

        const { rows } = await pool.query(
            `SELECT * FROM sp_accept_invite_existing_user($1, $2)`,
            [token, userId]
        );

        const result = rows[0];

        if (!result.success) {
            return res.status(400).json({ ok: false, error: result.message });
        }

        return res.json({
            ok: true,
            message: result.message,
            organization: {
                id: result.organization_id,
                name: result.organization_name,
                role: result.role_name
            }
        });
    } catch (err) {
        next(err);
    }
});

// ============================================
// REGISTER WITH INVITATION (New User)
// ============================================

// POST /invitations/register - Register new user with invitation token
router.post('/register', async (req: Request, res: Response, next: NextFunction) => {
    try {
        const { token, username, email, password } = req.body;

        if (!token || !username || !email || !password) {
            return res.status(400).json({ 
                ok: false, 
                error: 'token, username, email, and password are required' 
            });
        }

        if (String(password).length < 6) {
            return res.status(400).json({ 
                ok: false, 
                error: 'Password must be at least 6 characters' 
            });
        }

        const passwordHash = await bcrypt.hash(String(password), 10);

        const { rows } = await pool.query(
            `SELECT * FROM sp_register_with_invite($1, $2, $3, $4)`,
            [username, email.toLowerCase(), passwordHash, token]
        );

        const result = rows[0];

        if (!result.success) {
            return res.status(400).json({ ok: false, error: result.message });
        }

        // Generate JWT tokens
        const user_id = result.user_id;
        
        // Get role_id for JWT
        const r2 = await pool.query(
            'SELECT role_id FROM user_accounts WHERE user_id = $1',
            [user_id]
        );
        const role_id = Number(r2.rows[0].role_id);

        const accessToken = signAccessToken({ user_id, role_id });
        const refreshToken = signRefreshToken({ user_id, role_id });

        return res.json({
            ok: true,
            user_id,
            accessToken,
            refreshToken,
            organization: {
                id: result.organization_id,
                name: result.organization_name,
                role: result.role_name
            },
            message: 'Registration successful! Welcome to ' + result.organization_name
        });
    } catch (err: any) {
        if (err?.code === '23505') {
            return res.status(409).json({ ok: false, error: 'Username or email already exists' });
        }
        next(err);
    }
});

// ============================================
// INVITATION MANAGEMENT (Admin/Owner)
// ============================================

// GET /invitations/:orgId - Get organization's invites
router.get('/:orgId', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const userId = req.user!.user_id;
        const orgId = parseIntParam(req.params.orgId, 'orgId');

        const { rows } = await pool.query(
            `SELECT * FROM sp_get_org_pending_invites($1, $2)`,
            [orgId, userId]
        );

        return res.json({
            ok: true,
            invitations: rows
        });
    } catch (err: any) {
        if (err.code === '28000') {
            return res.status(403).json({ ok: false, error: 'Not authorized to view invitations' });
        }
        next(err);
    }
});

// POST /invitations/:inviteId/resend - Resend invitation email
router.post('/:inviteId/resend', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const userId = req.user!.user_id;
        const inviteId = parseIntParam(req.params.inviteId, 'inviteId');

        const { rows } = await pool.query(
            `SELECT * FROM sp_resend_invite($1, $2)`,
            [inviteId, userId]
        );

        if (rows.length === 0) {
            return res.status(404).json({ ok: false, error: 'Invitation not found' });
        }

        const invite = rows[0];

        // Send email
        const result = await emailService.sendInvitationEmail({
            to: invite.email,
            organizationName: invite.organization_name,
            inviteToken: invite.token,
            expiresAt: new Date(invite.expires_at)
        });

        // Update email_sent status
        if (result.success) {
            await pool.query(
                `UPDATE organization_invites 
                 SET email_sent = TRUE, email_sent_at = CURRENT_TIMESTAMP 
                 WHERE token = $1`,
                [invite.token]
            );
        }

        return res.json({
            ok: true,
            message: result.success ? 'Invitation resent successfully' : 'Invitation renewed but email failed',
            email: invite.email,
            expires_at: invite.expires_at,
            email_sent: result.success
        });
    } catch (err: any) {
        if (err.code === '28000') {
            return res.status(403).json({ ok: false, error: 'Not authorized to resend invitations' });
        }
        next(err);
    }
});

// DELETE /invitations/:inviteId - Revoke invitation
router.delete('/:inviteId', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const userId = req.user!.user_id;
        const inviteId = parseIntParam(req.params.inviteId, 'inviteId');

        await pool.query(
            `SELECT sp_revoke_invite($1, $2)`,
            [inviteId, userId]
        );

        return res.json({
            ok: true,
            message: 'Invitation revoked successfully'
        });
    } catch (err: any) {
        if (err.code === '28000') {
            return res.status(403).json({ ok: false, error: 'Not authorized to revoke invitations' });
        }
        next(err);
    }
});

// GET /invitations/batches/:orgId - Get batch upload history
router.get('/batches/:orgId', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
    try {
        const orgId = parseIntParam(req.params.orgId, 'orgId');

        const { rows } = await pool.query(
            `SELECT 
                ib.*,
                ua.username as created_by_name
             FROM invitation_batches ib
             JOIN user_accounts ua ON ib.created_by = ua.user_id
             WHERE ib.organization_id = $1
             ORDER BY ib.created_at DESC
             LIMIT 50`,
            [orgId]
        );

        return res.json({
            ok: true,
            batches: rows
        });
    } catch (err) {
        next(err);
    }
});

export default router;
