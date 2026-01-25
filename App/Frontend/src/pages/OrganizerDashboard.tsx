import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
    Building2,
    Users,
    TrendingUp,
    Plus,
    ArrowRight,
    BarChart3,
    Sparkles,
    Calendar,
    CheckCircle,
    X,
    UserPlus,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore } from '@/store/authStore';
import { organizationsApi, electionsApi, registrationApi } from '@/lib/api';
import type { Organization, Election, OrgMember } from '@/types';

export default function OrganizerDashboard() {
    const { user, currentOrganization } = useAuthStore();
    const [loading, setLoading] = useState(true);
    const [organizations, setOrganizations] = useState<Organization[]>([]);
    const [elections, setElections] = useState<Election[]>([]);
    const [stats, setStats] = useState({
        totalOrgs: 0,
        totalElections: 0,
        draftElections: 0,
        activeElections: 0,
    });
    const [showInviteModal, setShowInviteModal] = useState(false);
    const [inviteEmail, setInviteEmail] = useState('');
    const [inviteResult, setInviteResult] = useState<{ token: string, email: string } | null>(null);
    const [inviting, setInviting] = useState(false);

    // Join requests state
    const [joinRequests, setJoinRequests] = useState<any[]>([]);
    const [members, setMembers] = useState<OrgMember[]>([]);

    useEffect(() => {
        console.log('📊 Dashboard: currentOrganization changed:', currentOrganization?.organization_name);
        loadDashboardData();
    }, [currentOrganization]);

    const loadDashboardData = async () => {
        console.log('🔄 Loading dashboard data for org:', currentOrganization?.organization_name || 'NONE');
        setLoading(true);
        try {
            // Load organizations
            const orgsData = await organizationsApi.list();
            setOrganizations(orgsData);

            // Load elections for current organization
            if (currentOrganization) {
                const electionsData = await electionsApi.list(currentOrganization.organization_id);
                setElections(electionsData);

                setStats({
                    totalOrgs: orgsData.length,
                    totalElections: electionsData.length,
                    draftElections: electionsData.filter(e => e.status === 'DRAFT').length,
                    activeElections: electionsData.filter(e => e.status === 'OPEN').length,
                });
                console.log('✅ Dashboard data loaded:', { elections: electionsData.length, stats });
            } else {
                setStats({
                    totalOrgs: orgsData.length,
                    totalElections: 0,
                    draftElections: 0,
                    activeElections: 0,
                });
            }
        } catch (error: any) {
            toast.error('Failed to load dashboard data');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const handleInviteVoter = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!currentOrganization) return;

        setInviting(true);
        try {
            const result = await organizationsApi.createInvite(currentOrganization.organization_id, inviteEmail);
            setInviteResult(result);
            toast.success('Invitation created!');
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to create invitation');
        } finally {
            setInviting(false);
        }
    };

    const copyInviteToClipboard = () => {
        if (!inviteResult) return;
        navigator.clipboard.writeText(inviteResult.token);
        toast.success('Token copied to clipboard');
    };

    const closeInviteModal = () => {
        setShowInviteModal(false);
        setInviteResult(null);
        setInviteEmail('');
    };

    // Join request handlers
    const loadJoinRequests = async () => {
        if (!currentOrganization) return;

        try {
            const requests = await registrationApi.getJoinRequests(currentOrganization.organization_id);
            setJoinRequests(requests);
        } catch (error) {
            console.error('Failed to load join requests:', error);
        }
    };

    const handleApproveRequest = async (requestId: number) => {
        try {
            const result = await registrationApi.approveJoinRequest(requestId);
            toast.success(`Request approved! ${result.user_name} added to organization.`);
            loadJoinRequests();
            // No token needed
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to approve request');
        }
    };

    const handleRejectRequest = async (requestId: number) => {
        if (!confirm('Reject this join request?')) return;

        try {
            await registrationApi.rejectJoinRequest(requestId);
            toast.success('Request rejected');
            loadJoinRequests();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to reject request');
        }
    };



    const loadMembers = async () => {
        if (!currentOrganization) return;
        try {
            const data = await organizationsApi.getMembers(currentOrganization.organization_id);
            setMembers(data);
        } catch (error) {
            console.error('Failed to load members:', error);
        }
    };

    const handleRemoveMember = async (userId: number) => {
        if (!currentOrganization) return;
        if (!confirm('Are you sure you want to remove this member? This will also suspend their voter registration.')) return;

        try {
            await organizationsApi.removeMember(currentOrganization.organization_id, userId);
            toast.success('Member removed successfully');
            loadMembers();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to remove member');
        }
    };

    // Load join requests and members when organization changes
    useEffect(() => {
        if (currentOrganization) {
            loadJoinRequests();
            loadMembers();
        }
    }, [currentOrganization]);

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="spinner w-16 h-16 mx-auto mb-4"></div>
                    <p className="text-slate-600 font-medium">Loading your dashboard...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-8">
            {/* Premium Welcome Header */}
            <div className="relative overflow-hidden gradient-bg rounded-3xl p-8 text-white shadow-2xl">
                <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGRlZnM+PHBhdHRlcm4gaWQ9ImdyaWQiIHdpZHRoPSI2MCIgaGVpZ2h0PSI2MCIgcGF0dGVyblVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+PHBhdGggZD0iTSAxMCAwIEwgMCAwIDAgMTAiIGZpbGw9Im5vbmUiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS1vcGFjaXR5PSIwLjEiIHN0cm9rZS13aWR0aD0iMSIvPjwvcGF0dGVybj48L2RlZnM+PHJlY3Qgd2lkdGg9IjEwMCUiIGhlaWdodD0iMTAwJSIgZmlsbD0idXJsKCNncmlkKSIvPjwvc3ZnPg==')] opacity-20"></div>
                <div className="relative z-10">
                    <div className="flex items-center space-x-3 mb-3">
                        <Sparkles className="w-8 h-8" />
                        <h1 className="text-4xl font-black">
                            Welcome back, {user?.username}! 👋
                        </h1>
                    </div>
                    <p className="text-blue-100 text-lg">
                        {currentOrganization
                            ? `Managing ${currentOrganization.organization_name}`
                            : 'Select an organization to get started'
                        }
                    </p>
                </div>
            </div>

            {/* No Organizations CTA */}
            {organizations.length === 0 && (
                <div className="card border-purple-200 bg-purple-50">
                    <div className="flex flex-col md:flex-row items-center justify-between gap-6">
                        <div className="flex items-center space-x-4">
                            <div className="p-4 bg-white rounded-full shadow-md">
                                <Building2 className="w-8 h-8 text-purple-600" />
                            </div>
                            <div>
                                <h3 className="text-xl font-bold text-slate-900 mb-1">
                                    Create your first organization
                                </h3>
                                <p className="text-slate-600">
                                    Start by creating an organization to manage elections and voters.
                                </p>
                            </div>
                        </div>
                        <Link to="/organizations" className="btn-primary flex items-center bg-purple-600 hover:bg-purple-700 border-purple-600">
                            <Plus className="w-5 h-5 mr-2" />
                            Create Organization
                        </Link>
                    </div>
                </div>
            )}

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="stat-card group">
                    <div className="flex items-center justify-between mb-4">
                        <div className="icon-container from-purple-500 to-pink-600 group-hover:scale-110">
                            <BarChart3 className="w-6 h-6 text-white" />
                        </div>
                        <div className="text-right">
                            <p className="text-sm font-semibold text-slate-600 mb-1">Total Elections</p>
                            <p className="text-4xl font-black gradient-text">{stats.totalElections}</p>
                        </div>
                    </div>
                    <Link
                        to="/elections"
                        className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700 group-hover:translate-x-1 transition-transform"
                    >
                        View all <ArrowRight className="w-4 h-4 ml-1" />
                    </Link>
                </div>

                <div className="stat-card group">
                    <div className="flex items-center justify-between mb-4">
                        <div className="icon-container from-amber-500 to-orange-600 group-hover:scale-110">
                            <Calendar className="w-6 h-6 text-white" />
                        </div>
                        <div className="text-right">
                            <p className="text-sm font-semibold text-slate-600 mb-1">Draft Elections</p>
                            <p className="text-4xl font-black gradient-text">{stats.draftElections}</p>
                        </div>
                    </div>
                    <Link
                        to="/elections"
                        className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700 group-hover:translate-x-1 transition-transform"
                    >
                        Manage <ArrowRight className="w-4 h-4 ml-1" />
                    </Link>
                </div>

                <div className="stat-card group">
                    <div className="flex items-center justify-between mb-4">
                        <div className="icon-container from-emerald-500 to-green-600 group-hover:scale-110">
                            <TrendingUp className="w-6 h-6 text-white" />
                        </div>
                        <div className="text-right">
                            <p className="text-sm font-semibold text-slate-600 mb-1">Active Elections</p>
                            <p className="text-4xl font-black gradient-text">{stats.activeElections}</p>
                        </div>
                    </div>
                    <Link
                        to="/elections"
                        className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700 group-hover:translate-x-1 transition-transform"
                    >
                        Monitor <ArrowRight className="w-4 h-4 ml-1" />
                    </Link>
                </div>
            </div>

            {/* Quick Actions */}
            <div className="card">
                <h2 className="section-header">
                    <Sparkles className="w-7 h-7 text-blue-600" />
                    Quick Actions
                </h2>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <Link
                        to="/elections"
                        className="group relative overflow-hidden p-6 border-2 border-dashed border-slate-300 rounded-2xl hover:border-purple-500 hover:bg-gradient-to-br hover:from-purple-50 hover:to-pink-50 transition-all duration-300"
                    >
                        <div className="flex flex-col items-center text-center space-y-3">
                            <div className="p-4 bg-purple-100 rounded-2xl group-hover:scale-110 transition-transform">
                                <Plus className="w-8 h-8 text-purple-600" />
                            </div>
                            <span className="font-bold text-slate-700 group-hover:text-purple-600">Create Election</span>
                            <p className="text-sm text-slate-500">Set up a new election</p>
                        </div>
                    </Link>

                    <button
                        onClick={() => setShowInviteModal(true)}
                        disabled={!currentOrganization}
                        className={`group relative overflow-hidden p-6 border-2 border-dashed border-slate-300 rounded-2xl transition-all duration-300 ${!currentOrganization ? 'opacity-50 cursor-not-allowed bg-slate-50' : 'hover:border-emerald-500 hover:bg-gradient-to-br hover:from-emerald-50 hover:to-green-50'}`}
                    >
                        <div className="flex flex-col items-center text-center space-y-3">
                            <div className="p-4 bg-emerald-100 rounded-2xl group-hover:scale-110 transition-transform">
                                <Users className="w-8 h-8 text-emerald-600" />
                            </div>
                            <span className="font-bold text-slate-700 group-hover:text-emerald-600">Invite Voters</span>
                            <p className="text-sm text-slate-500">Generate invitation tokens</p>
                        </div>
                    </button>
                </div>
            </div>

            {/* Pending Join Requests */}
            {currentOrganization && (
                <div className="card">
                    <div className="flex items-center justify-between mb-6">
                        <h2 className="section-header mb-0">
                            <UserPlus className="w-7 h-7 text-blue-600" />
                            Pending Join Requests ({joinRequests.length})
                        </h2>
                    </div>

                    {joinRequests.length === 0 ? (
                        <div className="text-center py-8">
                            <CheckCircle className="w-12 h-12 text-green-500 mx-auto mb-3" />
                            <p className="text-slate-600">No pending join requests</p>
                        </div>
                    ) : (
                        <div className="space-y-4">
                            {joinRequests.map((request) => (
                                <div
                                    key={request.request_id}
                                    className="bg-slate-50 rounded-xl p-4 border border-slate-200 hover:border-blue-300 transition-colors"
                                >
                                    <div className="flex justify-between items-start">
                                        <div className="flex-1">
                                            <div className="flex items-center space-x-3 mb-2">
                                                <div className="w-10 h-10 rounded-full bg-gradient-to-r from-blue-600 to-indigo-600 flex items-center justify-center text-white font-bold">
                                                    {(request.username || 'U').charAt(0).toUpperCase()}
                                                </div>
                                                <div>
                                                    <p className="font-semibold text-slate-900">{request.username || 'Unknown'}</p>
                                                    <p className="text-sm text-slate-600">{request.email || 'No email'}</p>
                                                </div>
                                            </div>
                                            {request.request_message && (
                                                <div className="mt-3 bg-white rounded-lg p-3 border border-slate-200">
                                                    <p className="text-sm text-slate-700 italic">"{request.request_message}"</p>
                                                </div>
                                            )}
                                            <p className="text-xs text-slate-400 mt-2">
                                                Requested {new Date(request.created_at).toLocaleDateString()}
                                            </p>
                                        </div>
                                        <div className="flex space-x-2 ml-4">
                                            <button
                                                onClick={() => handleApproveRequest(request.request_id)}
                                                className="btn-primary text-sm px-4 py-2"
                                            >
                                                Approve
                                            </button>
                                            <button
                                                onClick={() => handleRejectRequest(request.request_id)}
                                                className="btn-secondary text-sm px-4 py-2 bg-red-600 hover:bg-red-700 text-white border-red-600"
                                            >
                                                Reject
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            )}

            {/* Organization Members */}
            {currentOrganization && (
                <div className="card">
                    <div className="flex items-center justify-between mb-6">
                        <h2 className="section-header mb-0">
                            <Users className="w-7 h-7 text-blue-600" />
                            Organization Members ({members.length})
                        </h2>
                    </div>

                    {members.length === 0 ? (
                        <div className="text-center py-8">
                            <Users className="w-12 h-12 text-slate-300 mx-auto mb-3" />
                            <p className="text-slate-600">No members found</p>
                        </div>
                    ) : (
                        <div className="overflow-x-auto">
                            <table className="w-full text-left">
                                <thead>
                                    <tr className="border-b border-slate-200">
                                        <th className="pb-4 font-semibold text-slate-700">Member</th>
                                        <th className="pb-4 font-semibold text-slate-700">Role</th>
                                        <th className="pb-4 font-semibold text-slate-700">Status</th>
                                        <th className="pb-4 font-semibold text-slate-700 text-right">Actions</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-slate-100">
                                    {members.map((member) => (
                                        <tr key={member.user_id} className="group hover:bg-slate-50 transition-colors">
                                            <td className="py-4">
                                                <div className="flex items-center space-x-3">
                                                    <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold">
                                                        {(member.username || 'U').charAt(0).toUpperCase()}
                                                    </div>
                                                    <div>
                                                        <p className="font-medium text-slate-900">{member.username || 'Unknown'}</p>
                                                        <p className="text-sm text-slate-500">{member.email || 'No email'}</p>
                                                    </div>
                                                </div>
                                            </td>
                                            <td className="py-4">
                                                <span className={`px-3 py-1 rounded-full text-xs font-bold ${member.role_name === 'OWNER' ? 'bg-purple-100 text-purple-700' :
                                                    member.role_name === 'ADMIN' ? 'bg-blue-100 text-blue-700' :
                                                        'bg-slate-100 text-slate-700'
                                                    }`}>
                                                    {member.role_name}
                                                </span>
                                            </td>
                                            <td className="py-4">
                                                <span className={`flex items-center text-sm ${member.is_active ? 'text-green-600' : 'text-slate-400'}`}>
                                                    <span className={`w-2 h-2 rounded-full mr-2 ${member.is_active ? 'bg-green-600' : 'bg-slate-400'}`} />
                                                    {member.is_active ? 'Active' : 'Inactive'}
                                                </span>
                                            </td>
                                            <td className="py-4 text-right">
                                                {member.user_id !== user?.user_id && member.role_name !== 'OWNER' && member.is_active && (
                                                    <button
                                                        onClick={() => handleRemoveMember(member.user_id)}
                                                        className="text-red-600 hover:text-red-700 text-sm font-semibold opacity-0 group-hover:opacity-100 transition-opacity"
                                                    >
                                                        Remove
                                                    </button>
                                                )}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    )}
                </div>
            )}

            {/* Recent Elections */}
            {elections.length > 0 && (
                <div className="card">
                    <div className="flex items-center justify-between mb-6">
                        <h2 className="section-header mb-0">
                            <Calendar className="w-7 h-7 text-blue-600" />
                            Recent Elections
                        </h2>
                        <Link
                            to="/elections"
                            className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700"
                        >
                            View all <ArrowRight className="w-4 h-4 ml-1" />
                        </Link>
                    </div>

                    <div className="space-y-4">
                        {elections.slice(0, 5).map((election) => (
                            <Link
                                key={election.election_id}
                                to={`/elections/${election.election_id}`}
                                className="block p-5 bg-gradient-to-r from-white to-slate-50 border-2 border-slate-200 rounded-2xl hover:border-blue-500 hover:shadow-xl transition-all duration-300 group"
                            >
                                <div className="flex items-start justify-between">
                                    <div className="flex-1">
                                        <h3 className="font-bold text-lg text-slate-900 mb-2 group-hover:text-blue-600 transition-colors">
                                            {election.election_name}
                                        </h3>
                                        <p className="text-sm text-slate-600 mb-3">
                                            {election.description || 'No description'}
                                        </p>
                                        <div className="flex items-center space-x-4 text-xs text-slate-500">
                                            <span>Created {new Date(election.created_at).toLocaleDateString()}</span>
                                        </div>
                                    </div>
                                    <div className="flex items-center space-x-3">
                                        <span className={`badge ${election.status === 'OPEN' ? 'bg-emerald-100 text-emerald-700 border-emerald-200' :
                                            election.status === 'DRAFT' ? 'bg-amber-100 text-amber-700 border-amber-200' :
                                                'bg-blue-100 text-blue-700 border-blue-200'
                                            } flex items-center space-x-1`}>
                                            {election.status === 'OPEN' && <CheckCircle className="w-4 h-4" />}
                                            <span>{election.status}</span>
                                        </span>
                                        <ArrowRight className="w-5 h-5 text-slate-400 group-hover:text-blue-600 group-hover:translate-x-1 transition-all" />
                                    </div>
                                </div>
                            </Link>
                        ))}
                    </div>
                </div>
            )}

            {/* Empty State */}
            {!currentOrganization && (
                <div className="card empty-state">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                        <Building2 className="w-10 h-10 text-blue-600" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">
                        No Organization Selected
                    </h3>
                    <p className="text-slate-600 mb-8 max-w-md mx-auto">
                        Select an organization from the header or create a new one to start managing elections
                    </p>
                    <Link to="/organizations" className="btn-primary inline-flex items-center">
                        <Plus className="w-5 h-5 mr-2" />
                        Create Organization
                    </Link>
                </div>
            )}

            {/* Invite Modal */}
            {showInviteModal && (
                <div className="modal-overlay" onClick={closeInviteModal}>
                    <div className="modal-content p-8 max-w-md" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">Invite Voter</h2>
                            <button onClick={closeInviteModal} className="p-2 hover:bg-slate-100 rounded-lg">
                                <X className="w-6 h-6" />
                            </button>
                        </div>

                        {!inviteResult ? (
                            <form onSubmit={handleInviteVoter} className="space-y-6">
                                <div className="form-group">
                                    <label className="label">Voter Email</label>
                                    <input
                                        type="email"
                                        className="input"
                                        value={inviteEmail}
                                        onChange={(e) => setInviteEmail(e.target.value)}
                                        placeholder="voter@example.com"
                                        required
                                    />
                                    <p className="text-xs text-slate-500 mt-1">
                                        We'll generate a secure token for this user to join.
                                    </p>
                                </div>
                                <div className="flex space-x-3 pt-4">
                                    <button
                                        type="submit"
                                        className="btn-primary flex-1"
                                        disabled={inviting || !inviteEmail}
                                    >
                                        {inviting ? 'Generating...' : 'Generate Invite Token'}
                                    </button>
                                </div>
                            </form>
                        ) : (
                            <div className="space-y-6">
                                <div className="alert-success">
                                    <p className="font-semibold">Invitation Generated!</p>
                                    <p className="text-sm">Share this token with the voter:</p>
                                </div>

                                <div className="p-4 bg-slate-100 rounded-xl border border-slate-200">
                                    <p className="text-xs text-slate-500 mb-1">Invitation Token</p>
                                    <div className="flex items-center justify-between">
                                        <code className="text-lg font-mono font-bold text-slate-900 select-all">
                                            {inviteResult.token}
                                        </code>
                                        <button
                                            onClick={copyInviteToClipboard}
                                            className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg ml-2"
                                            title="Copy to clipboard"
                                        >
                                            <Sparkles className="w-5 h-5" />
                                        </button>
                                    </div>
                                </div>

                                <div className="alert-info">
                                    <p className="text-sm">
                                        Only <strong>{inviteResult.email}</strong> can use this token. It expires in 7 days.
                                    </p>
                                </div>

                                <button onClick={closeInviteModal} className="btn-primary w-full">
                                    Done
                                </button>
                            </div>
                        )}
                    </div>
                </div>
            )}

            {/* Modal removed - Direct approval enabled */}
        </div>
    );
}
