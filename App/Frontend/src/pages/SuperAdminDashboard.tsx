import { useState, useEffect } from 'react';
import { Shield, CheckCircle, XCircle, Clock, Building2, FileText, ImageIcon, X, Users, BarChart3, Vote, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { adminApi } from '@/lib/api';
import type { OrgRequest } from '@/types';

type FilterTab = 'ALL' | 'PENDING' | 'APPROVED' | 'REJECTED';

interface PlatformStats {
    total_users: number;
    total_organizations: number;
    total_elections: number;
    total_votes: number;
    pending_requests: number;
}

export default function SuperAdminDashboard() {
    const [loading, setLoading] = useState(true);
    const [isSuperAdmin, setIsSuperAdmin] = useState<boolean | null>(null);
    // Stats
    const [stats, setStats] = useState<PlatformStats | null>(null);

    // Requests
    const [requests, setRequests] = useState<OrgRequest[]>([]);
    const [activeTab, setActiveTab] = useState<FilterTab>('PENDING');
    const [adminNotes, setAdminNotes] = useState<Record<number, string>>({});
    const [processing, setProcessing] = useState<number | null>(null);
    const [previewImage, setPreviewImage] = useState<string | null>(null);

    useEffect(() => {
        checkAccess();
    }, []);

    useEffect(() => {
        if (isSuperAdmin) {
            loadStats();
            loadRequests();
        }
    }, [isSuperAdmin]);

    useEffect(() => {
        if (isSuperAdmin) {
            loadRequests();
        }
    }, [activeTab]);

    const checkAccess = async () => {
        const isAdmin = await adminApi.checkSuperAdmin();
        setIsSuperAdmin(isAdmin);
        if (!isAdmin) setLoading(false);
    };

    const loadStats = async () => {
        try {
            const data = await adminApi.getStats();
            setStats(data.stats);
        } catch (error: any) {
            console.error('Failed to load stats:', error);
        } finally {
            setLoading(false);
        }
    };

    const loadRequests = async () => {
        try {
            const status = activeTab === 'ALL' ? undefined : activeTab;
            const data = await adminApi.getAllRequests(status);
            setRequests(data);
        } catch (error: any) {
            console.error('Failed to load requests:', error);
        }
    };

    const handleApprove = async (requestId: number) => {
        setProcessing(requestId);
        try {
            await adminApi.approveRequest(requestId, adminNotes[requestId]);
            toast.success('Organization request approved! Organization has been created.');
            setAdminNotes((prev) => ({ ...prev, [requestId]: '' }));
            loadRequests();
            loadStats();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to approve request');
        } finally {
            setProcessing(null);
        }
    };

    const handleReject = async (requestId: number) => {
        if (!adminNotes[requestId]?.trim()) {
            toast.error('Please provide a reason for rejection');
            return;
        }
        setProcessing(requestId);
        try {
            await adminApi.rejectRequest(requestId, adminNotes[requestId]);
            toast.success('Organization request rejected.');
            setAdminNotes((prev) => ({ ...prev, [requestId]: '' }));
            loadRequests();
            loadStats();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to reject request');
        } finally {
            setProcessing(null);
        }
    };

    const getStatusBadge = (status: string) => {
        switch (status) {
            case 'PENDING':
                return (
                    <span className="inline-flex items-center space-x-1 px-3 py-1 rounded-full text-sm font-semibold bg-yellow-100 text-yellow-800">
                        <Clock className="w-3.5 h-3.5" />
                        <span>Pending</span>
                    </span>
                );
            case 'APPROVED':
                return (
                    <span className="inline-flex items-center space-x-1 px-3 py-1 rounded-full text-sm font-semibold bg-green-100 text-green-800">
                        <CheckCircle className="w-3.5 h-3.5" />
                        <span>Approved</span>
                    </span>
                );
            case 'REJECTED':
                return (
                    <span className="inline-flex items-center space-x-1 px-3 py-1 rounded-full text-sm font-semibold bg-red-100 text-red-800">
                        <XCircle className="w-3.5 h-3.5" />
                        <span>Rejected</span>
                    </span>
                );
            default:
                return null;
        }
    };

    // Access denied
    if (isSuperAdmin === false) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-red-100 rounded-full mb-6">
                        <Shield className="w-10 h-10 text-red-500" />
                    </div>
                    <h2 className="text-2xl font-bold text-slate-900 mb-2">Access Denied</h2>
                    <p className="text-slate-600">You do not have super admin privileges to view this page.</p>
                </div>
            </div>
        );
    }

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="spinner w-16 h-16 mx-auto mb-4"></div>
                    <p className="text-slate-600 font-medium">Loading admin dashboard...</p>
                </div>
            </div>
        );
    }

    const requestFilterTabs: { key: FilterTab; label: string }[] = [
        { key: 'ALL', label: 'All' },
        { key: 'PENDING', label: 'Pending' },
        { key: 'APPROVED', label: 'Approved' },
        { key: 'REJECTED', label: 'Rejected' },
    ];

    return (
        <div className="space-y-6">
            {/* Header */}
            <div>
                <h1 className="text-4xl font-black gradient-text mb-2 flex items-center space-x-3">
                    <Shield className="w-10 h-10 text-blue-600" />
                    <span>Super Admin Dashboard</span>
                </h1>
                <p className="text-slate-600">Platform-wide management and analytics</p>
            </div>

            {/* Stats Cards - Always Visible */}
            {stats && (
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                    <div className="card text-center hover-lift">
                        <div className="inline-flex items-center justify-center w-12 h-12 bg-blue-100 rounded-2xl mb-3">
                            <Users className="w-6 h-6 text-blue-600" />
                        </div>
                        <p className="text-3xl font-black text-slate-900">{stats.total_users}</p>
                        <p className="text-sm text-slate-500 font-medium">Total Users</p>
                    </div>
                    <div className="card text-center hover-lift">
                        <div className="inline-flex items-center justify-center w-12 h-12 bg-indigo-100 rounded-2xl mb-3">
                            <Building2 className="w-6 h-6 text-indigo-600" />
                        </div>
                        <p className="text-3xl font-black text-slate-900">{stats.total_organizations}</p>
                        <p className="text-sm text-slate-500 font-medium">Organizations</p>
                    </div>
                    <div className="card text-center hover-lift">
                        <div className="inline-flex items-center justify-center w-12 h-12 bg-purple-100 rounded-2xl mb-3">
                            <BarChart3 className="w-6 h-6 text-purple-600" />
                        </div>
                        <p className="text-3xl font-black text-slate-900">{stats.total_elections}</p>
                        <p className="text-sm text-slate-500 font-medium">Elections</p>
                    </div>
                    <div className="card text-center hover-lift">
                        <div className="inline-flex items-center justify-center w-12 h-12 bg-green-100 rounded-2xl mb-3">
                            <Vote className="w-6 h-6 text-green-600" />
                        </div>
                        <p className="text-3xl font-black text-slate-900">{stats.total_votes}</p>
                        <p className="text-sm text-slate-500 font-medium">Votes Cast</p>
                    </div>
                    <div className="card text-center hover-lift">
                        <div className="inline-flex items-center justify-center w-12 h-12 bg-yellow-100 rounded-2xl mb-3">
                            <AlertCircle className="w-6 h-6 text-yellow-600" />
                        </div>
                        <p className="text-3xl font-black text-slate-900">{stats.pending_requests}</p>
                        <p className="text-sm text-slate-500 font-medium">Pending Requests</p>
                    </div>
                </div>
            )}

            {/* ===================== REQUESTS SECTION ===================== */}
                <div className="space-y-4">
                    {/* Request filter tabs */}
                    <div className="flex flex-wrap gap-2">
                        {requestFilterTabs.map((tab) => (
                            <button
                                key={tab.key}
                                onClick={() => setActiveTab(tab.key)}
                                className={`px-5 py-2.5 rounded-xl text-base font-bold tracking-wide transition-all ${
                                    activeTab === tab.key
                                        ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/30'
                                        : 'bg-slate-100 text-slate-700 hover:bg-slate-200 border border-slate-200'
                                }`}
                            >
                                {tab.label}
                            </button>
                        ))}
                    </div>

                    {requests.length === 0 ? (
                        <div className="card empty-state">
                            <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                                <FileText className="w-10 h-10 text-blue-600" />
                            </div>
                            <h3 className="text-2xl font-bold text-slate-900 mb-3">
                                No {activeTab !== 'ALL' ? activeTab.toLowerCase() : ''} requests
                            </h3>
                            <p className="text-slate-600">
                                {activeTab === 'PENDING'
                                    ? 'All pending requests have been reviewed.'
                                    : 'No organization requests match this filter.'}
                            </p>
                        </div>
                    ) : (
                        <div className="space-y-6">
                            {requests.map((req) => (
                                <div key={req.request_id} className="card hover-lift">
                                    <div className="flex flex-col lg:flex-row gap-6">
                                        {/* Left: Request Details */}
                                        <div className="flex-1 space-y-4">
                                            <div className="flex items-start justify-between">
                                                <div>
                                                    <h3 className="text-xl font-bold text-slate-900 flex items-center space-x-2">
                                                        <Building2 className="w-5 h-5 text-blue-600" />
                                                        <span>{req.organization_name}</span>
                                                    </h3>
                                                    <div className="flex items-center space-x-3 mt-1">
                                                        <span className="text-sm text-slate-500 bg-slate-100 px-2 py-0.5 rounded-lg">
                                                            {req.organization_type}
                                                        </span>
                                                        <span className="text-sm font-mono text-slate-500 bg-slate-100 px-2 py-0.5 rounded-lg">
                                                            {req.organization_code}
                                                        </span>
                                                    </div>
                                                </div>
                                                {getStatusBadge(req.status)}
                                            </div>

                                            {/* Requester Info */}
                                            <div className="flex items-center space-x-3 p-3 bg-slate-50 rounded-xl">
                                                <div className="w-10 h-10 rounded-full bg-gradient-to-r from-blue-600 to-indigo-600 flex items-center justify-center text-white font-bold">
                                                    {req.requester_username?.charAt(0).toUpperCase() || '?'}
                                                </div>
                                                <div>
                                                    <p className="font-semibold text-slate-900">{req.requester_username}</p>
                                                    <p className="text-xs text-slate-500">{req.requester_email}</p>
                                                </div>
                                            </div>

                                            {req.purpose && (
                                                <div>
                                                    <p className="text-sm font-semibold text-slate-700 mb-1">Purpose</p>
                                                    <p className="text-sm text-slate-600 bg-slate-50 p-3 rounded-xl">{req.purpose}</p>
                                                </div>
                                            )}

                                            {req.expected_members && (
                                                <div className="flex items-center space-x-2 text-sm text-slate-600">
                                                    <Users className="w-4 h-4" />
                                                    <span>Expected Members: <strong>{req.expected_members}</strong></span>
                                                </div>
                                            )}

                                            <p className="text-xs text-slate-400">
                                                Submitted on {new Date(req.created_at).toLocaleString()}
                                            </p>

                                            {req.admin_notes && req.status !== 'PENDING' && (
                                                <div className={`text-sm p-3 rounded-xl ${req.status === 'REJECTED' ? 'bg-red-50 text-red-700 border border-red-200' : 'bg-green-50 text-green-700 border border-green-200'}`}>
                                                    <span className="font-semibold">Admin Note:</span> {req.admin_notes}
                                                </div>
                                            )}
                                        </div>

                                        {/* Right: Proof Document */}
                                        <div className="lg:w-72 flex-shrink-0">
                                            {req.proof_document_url ? (
                                                <div>
                                                    <p className="text-sm font-semibold text-slate-700 mb-2">Proof Document</p>
                                                    <img
                                                        src={`/uploads/${req.proof_document_url}`}
                                                        alt="Proof document"
                                                        className="w-full h-48 object-cover rounded-xl border border-slate-200 cursor-pointer hover:opacity-90 transition-opacity shadow-sm"
                                                        onClick={() => setPreviewImage(`/uploads/${req.proof_document_url}`)}
                                                    />
                                                    <p className="text-xs text-blue-600 mt-1 cursor-pointer hover:underline" onClick={() => setPreviewImage(`/uploads/${req.proof_document_url}`)}>
                                                        Click to enlarge
                                                    </p>
                                                </div>
                                            ) : (
                                                <div className="flex flex-col items-center justify-center h-48 bg-slate-50 rounded-xl border-2 border-dashed border-slate-200">
                                                    <ImageIcon className="w-10 h-10 text-slate-300 mb-2" />
                                                    <p className="text-sm text-slate-400">No proof uploaded</p>
                                                </div>
                                            )}
                                        </div>
                                    </div>

                                    {/* Action Bar (only for PENDING) */}
                                    {req.status === 'PENDING' && (
                                        <div className="mt-6 pt-6 border-t border-slate-200 space-y-4">
                                            <div className="form-group">
                                                <label className="label text-sm">Admin Notes (required for rejection)</label>
                                                <textarea
                                                    value={adminNotes[req.request_id] || ''}
                                                    onChange={(e) => setAdminNotes((prev) => ({ ...prev, [req.request_id]: e.target.value }))}
                                                    className="input min-h-[60px]"
                                                    rows={2}
                                                    placeholder="Add notes about this request..."
                                                />
                                            </div>
                                            <div className="flex space-x-3">
                                                <button
                                                    onClick={() => handleApprove(req.request_id)}
                                                    disabled={processing === req.request_id}
                                                    className="flex-1 flex items-center justify-center space-x-2 px-4 py-3 bg-gradient-to-r from-green-500 to-emerald-600 text-white rounded-xl font-semibold hover:shadow-lg hover:shadow-green-500/30 transition-all duration-300 disabled:opacity-50"
                                                >
                                                    <CheckCircle className="w-5 h-5" />
                                                    <span>{processing === req.request_id ? 'Processing...' : 'Approve & Create Org'}</span>
                                                </button>
                                                <button
                                                    onClick={() => handleReject(req.request_id)}
                                                    disabled={processing === req.request_id}
                                                    className="flex-1 flex items-center justify-center space-x-2 px-4 py-3 bg-gradient-to-r from-red-500 to-rose-600 text-white rounded-xl font-semibold hover:shadow-lg hover:shadow-red-500/30 transition-all duration-300 disabled:opacity-50"
                                                >
                                                    <XCircle className="w-5 h-5" />
                                                    <span>{processing === req.request_id ? 'Processing...' : 'Reject'}</span>
                                                </button>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            ))}
                        </div>
                    )}
                </div>

            {/* Image Preview Modal */}
            {previewImage && (
                <div className="modal-overlay" onClick={() => setPreviewImage(null)}>
                    <div className="relative max-w-4xl max-h-[90vh] p-2" onClick={(e) => e.stopPropagation()}>
                        <button
                            onClick={() => setPreviewImage(null)}
                            className="absolute top-4 right-4 z-10 p-2 bg-black/50 text-white rounded-full hover:bg-black/70 transition-colors"
                        >
                            <X className="w-6 h-6" />
                        </button>
                        <img
                            src={previewImage}
                            alt="Proof document full size"
                            className="max-w-full max-h-[85vh] object-contain rounded-2xl shadow-2xl"
                        />
                    </div>
                </div>
            )}
        </div>
    );
}
