import { useState, useEffect } from 'react';
import { Mail, Clock, CheckCircle, XCircle, AlertCircle, RefreshCw, Trash2, Loader, Upload } from 'lucide-react';
import toast from 'react-hot-toast';
import { invitationsApi } from '@/lib/api';
import type { Invitation } from '@/types';
import CSVUploadModal from './CSVUploadModal';

interface InvitationManagerProps {
    organizationId: number;
    organizationName: string;
    isOwnerOrAdmin: boolean;
}

export default function InvitationManager({
    organizationId,
    organizationName,
    isOwnerOrAdmin,
}: InvitationManagerProps) {
    const [invitations, setInvitations] = useState<Invitation[]>([]);
    const [loading, setLoading] = useState(true);
    const [showCSVModal, setShowCSVModal] = useState(false);
    const [resendingId, setResendingId] = useState<number | null>(null);
    const [revokingId, setRevokingId] = useState<number | null>(null);

    useEffect(() => {
        if (isOwnerOrAdmin) {
            loadInvitations();
        }
    }, [organizationId, isOwnerOrAdmin]);

    const loadInvitations = async () => {
        try {
            const data = await invitationsApi.getOrgInvitations(organizationId);
            setInvitations(data);
        } catch (error: any) {
            console.error('Failed to load invitations:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleResend = async (inviteId: number) => {
        setResendingId(inviteId);
        try {
            const result = await invitationsApi.resend(inviteId);
            toast.success(`Invitation resent to ${result.email}`);
            loadInvitations();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to resend invitation');
        } finally {
            setResendingId(null);
        }
    };

    const handleRevoke = async (inviteId: number) => {
        if (!confirm('Are you sure you want to revoke this invitation?')) return;

        setRevokingId(inviteId);
        try {
            await invitationsApi.revoke(inviteId);
            toast.success('Invitation revoked');
            loadInvitations();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to revoke invitation');
        } finally {
            setRevokingId(null);
        }
    };

    const getStatusIcon = (status: string) => {
        switch (status) {
            case 'PENDING':
                return <Clock className="w-4 h-4 text-yellow-600" />;
            case 'ACCEPTED':
                return <CheckCircle className="w-4 h-4 text-green-600" />;
            case 'EXPIRED':
                return <AlertCircle className="w-4 h-4 text-red-600" />;
            case 'REVOKED':
                return <XCircle className="w-4 h-4 text-slate-600" />;
            default:
                return <Clock className="w-4 h-4 text-slate-600" />;
        }
    };

    const getStatusBadge = (status: string) => {
        const baseClasses = 'inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium space-x-1';
        switch (status) {
            case 'PENDING':
                return `${baseClasses} bg-yellow-100 text-yellow-700`;
            case 'ACCEPTED':
                return `${baseClasses} bg-green-100 text-green-700`;
            case 'EXPIRED':
                return `${baseClasses} bg-red-100 text-red-700`;
            case 'REVOKED':
                return `${baseClasses} bg-slate-100 text-slate-700`;
            default:
                return `${baseClasses} bg-slate-100 text-slate-700`;
        }
    };

    const formatDate = (dateStr: string) => {
        return new Date(dateStr).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
        });
    };

    const isExpired = (expiresAt: string) => {
        return new Date(expiresAt) < new Date();
    };

    if (!isOwnerOrAdmin) {
        return null;
    }

    const pendingInvites = invitations.filter(inv => inv.status === 'PENDING');

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h3 className="text-lg font-semibold text-slate-900">Invitations</h3>
                    <p className="text-sm text-slate-600">Manage member invitations for this organization</p>
                </div>
                <button
                    onClick={() => setShowCSVModal(true)}
                    className="btn-primary flex items-center space-x-2"
                >
                    <Upload className="w-4 h-4" />
                    <span>Bulk Invite (CSV)</span>
                </button>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-4 gap-4">
                <div className="p-4 bg-yellow-50 rounded-xl">
                    <Clock className="w-5 h-5 text-yellow-600 mb-2" />
                    <p className="text-2xl font-bold text-yellow-700">{pendingInvites.length}</p>
                    <p className="text-sm text-yellow-600">Pending</p>
                </div>
                <div className="p-4 bg-green-50 rounded-xl">
                    <CheckCircle className="w-5 h-5 text-green-600 mb-2" />
                    <p className="text-2xl font-bold text-green-700">
                        {invitations.filter(i => i.status === 'ACCEPTED').length}
                    </p>
                    <p className="text-sm text-green-600">Accepted</p>
                </div>
                <div className="p-4 bg-red-50 rounded-xl">
                    <AlertCircle className="w-5 h-5 text-red-600 mb-2" />
                    <p className="text-2xl font-bold text-red-700">
                        {invitations.filter(i => i.status === 'EXPIRED').length}
                    </p>
                    <p className="text-sm text-red-600">Expired</p>
                </div>
                <div className="p-4 bg-blue-50 rounded-xl">
                    <Mail className="w-5 h-5 text-blue-600 mb-2" />
                    <p className="text-2xl font-bold text-blue-700">
                        {invitations.filter(i => i.email_sent).length}
                    </p>
                    <p className="text-sm text-blue-600">Emails Sent</p>
                </div>
            </div>

            {/* Pending Invitations */}
            {loading ? (
                <div className="flex items-center justify-center py-12">
                    <Loader className="w-8 h-8 text-blue-600 animate-spin" />
                </div>
            ) : invitations.length === 0 ? (
                <div className="text-center py-12 bg-slate-50 rounded-xl">
                    <Mail className="w-12 h-12 text-slate-400 mx-auto mb-4" />
                    <h4 className="text-lg font-semibold text-slate-900">No Invitations Yet</h4>
                    <p className="text-slate-600 mt-2">Use the bulk invite feature to invite members via CSV</p>
                </div>
            ) : (
                <div className="bg-white border rounded-xl overflow-hidden">
                    <table className="w-full">
                        <thead className="bg-slate-50">
                            <tr>
                                <th className="px-4 py-3 text-left text-sm font-semibold text-slate-600">Email</th>
                                <th className="px-4 py-3 text-left text-sm font-semibold text-slate-600">Role</th>
                                <th className="px-4 py-3 text-left text-sm font-semibold text-slate-600">Status</th>
                                <th className="px-4 py-3 text-left text-sm font-semibold text-slate-600">Email Sent</th>
                                <th className="px-4 py-3 text-left text-sm font-semibold text-slate-600">Expires</th>
                                <th className="px-4 py-3 text-right text-sm font-semibold text-slate-600">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {invitations.map((invite) => (
                                <tr key={invite.invite_id} className="hover:bg-slate-50">
                                    <td className="px-4 py-3">
                                        <span className="text-sm text-slate-900">{invite.email}</span>
                                    </td>
                                    <td className="px-4 py-3">
                                        <span className="text-sm text-slate-600">{invite.role_name}</span>
                                    </td>
                                    <td className="px-4 py-3">
                                        <span className={getStatusBadge(invite.status)}>
                                            {getStatusIcon(invite.status)}
                                            <span>{invite.status}</span>
                                        </span>
                                    </td>
                                    <td className="px-4 py-3">
                                        {invite.email_sent ? (
                                            <span className="text-green-600 text-sm flex items-center space-x-1">
                                                <CheckCircle className="w-4 h-4" />
                                                <span>Sent</span>
                                            </span>
                                        ) : (
                                            <span className="text-slate-400 text-sm">Not sent</span>
                                        )}
                                    </td>
                                    <td className="px-4 py-3">
                                        <span className={`text-sm ${isExpired(invite.expires_at) ? 'text-red-600' : 'text-slate-600'}`}>
                                            {formatDate(invite.expires_at)}
                                        </span>
                                    </td>
                                    <td className="px-4 py-3">
                                        <div className="flex items-center justify-end space-x-2">
                                            {invite.status === 'PENDING' && (
                                                <>
                                                    <button
                                                        onClick={() => handleResend(invite.invite_id)}
                                                        disabled={resendingId === invite.invite_id}
                                                        className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                                                        title="Resend invitation"
                                                    >
                                                        {resendingId === invite.invite_id ? (
                                                            <Loader className="w-4 h-4 animate-spin" />
                                                        ) : (
                                                            <RefreshCw className="w-4 h-4" />
                                                        )}
                                                    </button>
                                                    <button
                                                        onClick={() => handleRevoke(invite.invite_id)}
                                                        disabled={revokingId === invite.invite_id}
                                                        className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                                        title="Revoke invitation"
                                                    >
                                                        {revokingId === invite.invite_id ? (
                                                            <Loader className="w-4 h-4 animate-spin" />
                                                        ) : (
                                                            <Trash2 className="w-4 h-4" />
                                                        )}
                                                    </button>
                                                </>
                                            )}
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            {/* CSV Upload Modal */}
            <CSVUploadModal
                isOpen={showCSVModal}
                onClose={() => setShowCSVModal(false)}
                organizationId={organizationId}
                organizationName={organizationName}
                onSuccess={loadInvitations}
            />
        </div>
    );
}
