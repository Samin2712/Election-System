import nodemailer from 'nodemailer';

interface EmailConfig {
    host: string;
    port: number;
    secure: boolean;
    auth: {
        user: string;
        pass: string;
    };
}

interface InvitationEmailData {
    to: string;
    organizationName: string;
    inviteToken: string;
    expiresAt: Date;
    inviterName?: string;
}

class EmailService {
    private transporter: nodemailer.Transporter | null = null;
    private isConfigured: boolean = false;
    private frontendUrl: string;

    constructor() {
        this.frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5173';
        this.initializeTransporter();
    }

    private initializeTransporter() {
        const host = process.env.SMTP_HOST;
        const port = parseInt(process.env.SMTP_PORT || '587');
        const user = process.env.SMTP_USER;
        const pass = process.env.SMTP_PASS;

        if (host && user && pass) {
            this.transporter = nodemailer.createTransport({
                host,
                port,
                secure: port === 465,
                auth: { user, pass },
            });
            this.isConfigured = true;
            console.log('📧 Email service configured');
        } else {
            console.log('📧 Email service not configured - emails will be logged to console');
            this.isConfigured = false;
        }
    }

    async sendInvitationEmail(data: InvitationEmailData): Promise<{ success: boolean; message: string }> {
        const inviteLink = `${this.frontendUrl}/invite?token=${data.inviteToken}`;
        const expiresText = this.formatDate(data.expiresAt);

        const htmlContent = this.getInvitationHtmlTemplate({
            organizationName: data.organizationName,
            inviteLink,
            expiresText,
            inviterName: data.inviterName,
        });

        const textContent = this.getInvitationTextTemplate({
            organizationName: data.organizationName,
            inviteLink,
            expiresText,
            inviterName: data.inviterName,
        });

        const mailOptions = {
            from: process.env.SMTP_FROM || '"Election System" <noreply@elections.com>',
            to: data.to,
            subject: `Invitation to Join ${data.organizationName}`,
            text: textContent,
            html: htmlContent,
        };

        if (this.isConfigured && this.transporter) {
            try {
                await this.transporter.sendMail(mailOptions);
                console.log(`✅ Email sent to ${data.to}`);
                return { success: true, message: 'Email sent successfully' };
            } catch (error: any) {
                console.error(`❌ Failed to send email to ${data.to}:`, error.message);
                return { success: false, message: error.message };
            }
        } else {
            // Log to console for development
            console.log('\n========== EMAIL LOG ==========');
            console.log(`To: ${data.to}`);
            console.log(`Subject: ${mailOptions.subject}`);
            console.log(`Invite Link: ${inviteLink}`);
            console.log(`Expires: ${expiresText}`);
            console.log('================================\n');
            return { success: true, message: 'Email logged (SMTP not configured)' };
        }
    }

    async sendBulkInvitations(
        emails: string[],
        organizationName: string,
        tokens: Map<string, string>,
        expiresAt: Date,
        inviterName?: string
    ): Promise<{ sent: number; failed: number; results: Array<{ email: string; success: boolean; message: string }> }> {
        const results: Array<{ email: string; success: boolean; message: string }> = [];
        let sent = 0;
        let failed = 0;

        for (const email of emails) {
            const token = tokens.get(email);
            if (!token) {
                results.push({ email, success: false, message: 'No token generated' });
                failed++;
                continue;
            }

            const result = await this.sendInvitationEmail({
                to: email,
                organizationName,
                inviteToken: token,
                expiresAt,
                inviterName,
            });

            results.push({ email, ...result });
            if (result.success) {
                sent++;
            } else {
                failed++;
            }

            // Small delay to avoid rate limiting
            await new Promise(resolve => setTimeout(resolve, 100));
        }

        return { sent, failed, results };
    }

    private formatDate(date: Date): string {
        return new Intl.DateTimeFormat('en-US', {
            dateStyle: 'full',
            timeStyle: 'short',
        }).format(date);
    }

    private getInvitationHtmlTemplate(data: {
        organizationName: string;
        inviteLink: string;
        expiresText: string;
        inviterName?: string;
    }): string {
        return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Invitation to ${data.organizationName}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: #ffffff;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            width: 60px;
            height: 60px;
            background: linear-gradient(135deg, #3B82F6, #6366F1);
            border-radius: 12px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 20px;
        }
        .logo svg {
            width: 32px;
            height: 32px;
            fill: white;
        }
        h1 {
            color: #1a1a1a;
            font-size: 24px;
            margin: 0 0 10px;
        }
        .org-name {
            color: #3B82F6;
            font-weight: bold;
        }
        .message {
            background-color: #f8fafc;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .btn {
            display: inline-block;
            background: linear-gradient(135deg, #3B82F6, #6366F1);
            color: white !important;
            text-decoration: none;
            padding: 14px 32px;
            border-radius: 8px;
            font-weight: 600;
            font-size: 16px;
            margin: 20px 0;
        }
        .btn:hover {
            opacity: 0.9;
        }
        .link-text {
            word-break: break-all;
            color: #64748b;
            font-size: 12px;
            margin-top: 10px;
        }
        .expires {
            color: #ef4444;
            font-size: 14px;
            margin-top: 20px;
        }
        .footer {
            text-align: center;
            color: #94a3b8;
            font-size: 12px;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e2e8f0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">
                <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                </svg>
            </div>
            <h1>You're Invited!</h1>
        </div>
        
        <div class="message">
            <p>Hello,</p>
            <p>You've been invited to join <span class="org-name">${data.organizationName}</span> on the Election Management System.</p>
            ${data.inviterName ? `<p><em>Invited by: ${data.inviterName}</em></p>` : ''}
        </div>
        
        <div style="text-align: center;">
            <a href="${data.inviteLink}" class="btn">Accept Invitation</a>
            <p class="link-text">Or copy this link: ${data.inviteLink}</p>
        </div>
        
        <p class="expires">⚠️ This invitation expires on ${data.expiresText}</p>
        
        <div class="footer">
            <p>If you didn't expect this invitation, you can safely ignore this email.</p>
            <p>© ${new Date().getFullYear()} Election Management System</p>
        </div>
    </div>
</body>
</html>`;
    }

    private getInvitationTextTemplate(data: {
        organizationName: string;
        inviteLink: string;
        expiresText: string;
        inviterName?: string;
    }): string {
        return `
You're Invited to ${data.organizationName}

Hello,

You've been invited to join ${data.organizationName} on the Election Management System.
${data.inviterName ? `\nInvited by: ${data.inviterName}` : ''}

Click the link below to accept the invitation:
${data.inviteLink}

⚠️ This invitation expires on ${data.expiresText}

If you didn't expect this invitation, you can safely ignore this email.

© ${new Date().getFullYear()} Election Management System
`;
    }
}

export const emailService = new EmailService();
