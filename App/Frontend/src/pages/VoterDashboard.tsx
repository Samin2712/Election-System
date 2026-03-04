import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
    Vote,
    TrendingUp,
    CheckCircle,
    ArrowRight,
    Sparkles,
    Trophy,
    Calendar,
    Building2,
    X,
    Plus,
    Play
} from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore } from '@/store/authStore';
import { electionsApi, votingApi, registrationApi } from '@/lib/api';
import type { Election, VoterStatusResponse } from '@/types';
import CountdownDisplay from '@/components/CountdownDisplay';

export default function VoterDashboard() {
    const { user, currentOrganization } = useAuthStore();
    const [loading, setLoading] = useState(true);
    const [elections, setElections] = useState<Election[]>([]);
    const [voterStatus, setVoterStatus] = useState<VoterStatusResponse | null>(null);
    const [showJoinModal, setShowJoinModal] = useState(false);
    const [joinToken, setJoinToken] = useState('');
    const [joining, setJoining] = useState(false);

    useEffect(() => {
        loadDashboardData();
    }, [currentOrganization]);

    const loadDashboardData = async () => {
        if (!currentOrganization) {
            setLoading(false);
            return;
        }

        setLoading(true);
        try {
            // Load elections for current organization only
            const orgElections = await electionsApi.list(currentOrganization.organization_id);
            setElections(orgElections);

            // Check voter status for current organization
            try {
                const status = await votingApi.getStatus(currentOrganization.organization_id);
                setVoterStatus(status);
            } catch {
                setVoterStatus(null);
            }
        } catch (error: any) {
            toast.error('Failed to load dashboard data');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const handleJoinOrganization = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!joinToken.trim()) {
            toast.error('Please enter a registration token');
            return;
        }

        setJoining(true);
        try {
            const result = await registrationApi.completeRegistration(joinToken);
            toast.success(`Successfully joined ${result.organization_name}!`);
            setShowJoinModal(false);
            setJoinToken('');
            window.location.reload();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Invalid or expired registration token');
        } finally {
            setJoining(false);
        }
    };

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

    // No organization selected
    if (!currentOrganization) {
        return (
            <div className="space-y-8">
                <div className="relative overflow-hidden gradient-bg rounded-3xl p-8 text-white shadow-2xl">
                    <div className="relative z-10">
                        <div className="flex items-center space-x-3 mb-3">
                            <Sparkles className="w-8 h-8" />
                            <h1 className="text-4xl font-black">Welcome, {user?.username}! 🗳️</h1>
                        </div>
                        <p className="text-blue-100 text-lg">Select an organization to view elections</p>
                    </div>
                </div>

                <div className="card border-blue-200 bg-blue-50">
                    <div className="flex flex-col md:flex-row items-center justify-between gap-6">
                        <div className="flex items-center space-x-4">
                            <div className="p-4 bg-white rounded-full shadow-md">
                                <Building2 className="w-8 h-8 text-blue-600" />
                            </div>
                            <div>
                                <h3 className="text-xl font-bold text-slate-900 mb-1">
                                    No organization selected
                                </h3>
                                <p className="text-slate-600">
                                    Select an organization from the dropdown above or join a new one.
                                </p>
                            </div>
                        </div>
                        <div className="flex space-x-3">
                            <Link to="/organizations" className="btn-primary flex items-center">
                                <Plus className="w-5 h-5 mr-2" />
                                Browse Organizations
                            </Link>
                            <button
                                onClick={() => setShowJoinModal(true)}
                                className="btn-secondary flex items-center bg-white"
                            >
                                <CheckCircle className="w-5 h-5 mr-2" />
                                Use Token
                            </button>
                        </div>
                    </div>
                </div>

                {showJoinModal && (
                    <JoinModal
                        joinToken={joinToken}
                        setJoinToken={setJoinToken}
                        joining={joining}
                        onSubmit={handleJoinOrganization}
                        onClose={() => setShowJoinModal(false)}
                    />
                )}
            </div>
        );
    }

    const openElections = elections.filter(e => e.status === 'OPEN');
    const scheduledElections = elections.filter(e => e.status === 'SCHEDULED');
    const closedElections = elections.filter(e => e.status === 'CLOSED');

    return (
        <div className="space-y-8">
            {/* Welcome Header */}
            <div className="relative overflow-hidden gradient-bg rounded-3xl p-8 text-white shadow-2xl">
                <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGRlZnM+PHBhdHRlcm4gaWQ9ImdyaWQiIHdpZHRoPSI2MCIgaGVpZ2h0PSI2MCIgcGF0dGVyblVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+PHBhdGggZD0iTSAxMCAwIEwgMCAwIDAgMTAiIGZpbGw9Im5vbmUiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS1vcGFjaXR5PSIwLjEiIHN0cm9rZS13aWR0aD0iMSIvPjwvcGF0dGVybj48L2RlZnM+PHJlY3Qgd2lkdGg9IjEwMCUiIGhlaWdodD0iMTAwJSIgZmlsbD0idXJsKCNncmlkKSIvPjwvc3ZnPg==')] opacity-20"></div>
                <div className="relative z-10">
                    <div className="flex items-center space-x-3 mb-3">
                        <Sparkles className="w-8 h-8" />
                        <h1 className="text-4xl font-black">Welcome, {user?.username}! 🗳️</h1>
                    </div>
                    <p className="text-blue-100 text-lg">
                        {currentOrganization.organization_name} - Your voice matters!
                    </p>
                </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div className="stat-card group">
                    <div className="flex items-center justify-between mb-4">
                        <div className="icon-container from-emerald-500 to-green-600 group-hover:scale-110">
                            <Vote className="w-6 h-6 text-white" />
                        </div>
                        <div className="text-right">
                            <p className="text-sm font-semibold text-slate-600 mb-1">Active Elections</p>
                            <p className="text-4xl font-black gradient-text">{openElections.length}</p>
                        </div>
                    </div>
                    <Link
                        to="/vote"
                        className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700 group-hover:translate-x-1 transition-transform"
                    >
                        Cast your vote <ArrowRight className="w-4 h-4 ml-1" />
                    </Link>
                </div>

                <div className="stat-card group">
                    <div className="flex items-center justify-between mb-4">
                        <div className="icon-container from-amber-500 to-orange-600 group-hover:scale-110">
                            <Calendar className="w-6 h-6 text-white" />
                        </div>
                        <div className="text-right">
                            <p className="text-sm font-semibold text-slate-600 mb-1">Upcoming</p>
                            <p className="text-4xl font-black gradient-text">{scheduledElections.length}</p>
                        </div>
                    </div>
                    <span className="flex items-center text-sm text-slate-500">
                        Scheduled elections
                    </span>
                </div>

                <div className="stat-card group">
                    <div className="flex items-center justify-between mb-4">
                        <div className="icon-container from-blue-500 to-indigo-600 group-hover:scale-110">
                            <Trophy className="w-6 h-6 text-white" />
                        </div>
                        <div className="text-right">
                            <p className="text-sm font-semibold text-slate-600 mb-1">Completed</p>
                            <p className="text-4xl font-black gradient-text">{closedElections.length}</p>
                        </div>
                    </div>
                    <Link
                        to="/elections"
                        className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700 group-hover:translate-x-1 transition-transform"
                    >
                        View results <ArrowRight className="w-4 h-4 ml-1" />
                    </Link>
                </div>

                <div className="stat-card group">
                    <div className="flex items-center justify-between mb-4">
                        <div className="icon-container from-purple-500 to-pink-600 group-hover:scale-110">
                            <CheckCircle className="w-6 h-6 text-white" />
                        </div>
                        <div className="text-right">
                            <p className="text-sm font-semibold text-slate-600 mb-1">Voter Status</p>
                            <p className="text-lg font-bold text-slate-900">
                                {voterStatus?.registered ? 'Active ✓' : 'Inactive'}
                            </p>
                        </div>
                    </div>
                    <Link
                        to="/vote"
                        className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700 group-hover:translate-x-1 transition-transform"
                    >
                        Open Voter Portal <ArrowRight className="w-4 h-4 ml-1" />
                    </Link>
                </div>
            </div>

            {/* Active Elections Section */}
            {openElections.length > 0 ? (
                <div className="card">
                    <div className="flex items-center justify-between mb-6">
                        <h2 className="section-header mb-0">
                            <TrendingUp className="w-7 h-7 text-emerald-600" />
                            Active Elections - Vote Now!
                        </h2>
                        <Link
                            to="/vote"
                            className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700"
                        >
                            Vote <ArrowRight className="w-4 h-4 ml-1" />
                        </Link>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        {openElections.map((election) => (
                            <Link
                                key={election.election_id}
                                to="/vote"
                                className="block p-5 bg-gradient-to-br from-emerald-50 to-green-50 border-2 border-emerald-200 rounded-2xl hover:border-emerald-500 hover:shadow-xl transition-all duration-300 group"
                            >
                                <div className="flex items-start justify-between mb-3">
                                    <div className="flex-1">
                                        <div className="flex items-center space-x-2 mb-2">
                                            <span className="badge bg-emerald-100 text-emerald-700 border-emerald-200 flex items-center space-x-1">
                                                <CheckCircle className="w-3 h-3" />
                                                <span>OPEN</span>
                                            </span>
                                        </div>
                                        <h3 className="font-bold text-lg text-slate-900 mb-2 group-hover:text-emerald-600 transition-colors">
                                            {election.election_name}
                                        </h3>
                                        <p className="text-sm text-slate-600 mb-3">
                                            {election.description || 'No description'}
                                        </p>
                                        <CountdownDisplay
                                            status={election.status}
                                            startDatetime={election.start_datetime}
                                            endDatetime={election.end_datetime}
                                        />
                                    </div>
                                    <ArrowRight className="w-5 h-5 text-emerald-400 group-hover:text-emerald-600 group-hover:translate-x-1 transition-all flex-shrink-0 ml-2" />
                                </div>
                            </Link>
                        ))}
                    </div>
                </div>
            ) : (
                <div className="card empty-state">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                        <Vote className="w-10 h-10 text-blue-600" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">No Active Elections</h3>
                    <p className="text-slate-600">
                        There are currently no open elections in {currentOrganization.organization_name}. Check back later!
                    </p>
                </div>
            )}

            {/* Upcoming Elections */}
            {scheduledElections.length > 0 && (
                <div className="card">
                    <h2 className="section-header">
                        <Calendar className="w-7 h-7 text-amber-600" />
                        Upcoming Elections
                    </h2>
                    <div className="space-y-3">
                        {scheduledElections.map((election) => (
                            <div
                                key={election.election_id}
                                className="p-4 bg-gradient-to-r from-amber-50 to-orange-50 border-2 border-amber-200 rounded-xl"
                            >
                                <div className="flex items-center justify-between">
                                    <div className="flex-1">
                                        <div className="flex items-center space-x-2 mb-2">
                                            <span className="badge bg-amber-100 text-amber-700 border-amber-200 flex items-center space-x-1">
                                                <Play className="w-3 h-3" />
                                                <span>SCHEDULED</span>
                                            </span>
                                        </div>
                                        <h4 className="font-semibold text-slate-900 mb-2">{election.election_name}</h4>
                                        <CountdownDisplay
                                            status={election.status}
                                            startDatetime={election.start_datetime}
                                            endDatetime={election.end_datetime}
                                        />
                                    </div>
                                    {election.start_datetime && (
                                        <div className="text-right text-sm text-slate-500">
                                            <p>Starts</p>
                                            <p className="font-semibold">{new Date(election.start_datetime).toLocaleDateString()}</p>
                                        </div>
                                    )}
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* Recent Results */}
            {closedElections.length > 0 && (
                <div className="card">
                    <div className="flex items-center justify-between mb-6">
                        <h2 className="section-header mb-0">
                            <Trophy className="w-7 h-7 text-blue-600" />
                            Recent Results
                        </h2>
                        <Link
                            to="/elections"
                            className="flex items-center text-sm font-semibold text-blue-600 hover:text-blue-700"
                        >
                            View all <ArrowRight className="w-4 h-4 ml-1" />
                        </Link>
                    </div>
                    <div className="space-y-3">
                        {closedElections.slice(0, 3).map((election) => (
                            <Link
                                key={election.election_id}
                                to={`/results/${election.election_id}`}
                                className="block p-4 bg-gradient-to-r from-blue-50 to-indigo-50 border-2 border-blue-200 rounded-xl hover:border-blue-500 hover:shadow-lg transition-all group"
                            >
                                <div className="flex items-center justify-between">
                                    <div>
                                        <div className="flex items-center space-x-2 mb-1">
                                            <span className="badge bg-blue-100 text-blue-700 border-blue-200 flex items-center space-x-1">
                                                <Trophy className="w-3 h-3" />
                                                <span>CLOSED</span>
                                            </span>
                                        </div>
                                        <h4 className="font-semibold text-slate-900 group-hover:text-blue-600 transition-colors">
                                            {election.election_name}
                                        </h4>
                                    </div>
                                    <ArrowRight className="w-5 h-5 text-blue-400 group-hover:text-blue-600 group-hover:translate-x-1 transition-all" />
                                </div>
                            </Link>
                        ))}
                    </div>
                </div>
            )}

            {/* Join Modal */}
            {showJoinModal && (
                <JoinModal
                    joinToken={joinToken}
                    setJoinToken={setJoinToken}
                    joining={joining}
                    onSubmit={handleJoinOrganization}
                    onClose={() => setShowJoinModal(false)}
                />
            )}
        </div>
    );
}

// Extracted Join Modal Component
function JoinModal({
    joinToken,
    setJoinToken,
    joining,
    onSubmit,
    onClose
}: {
    joinToken: string;
    setJoinToken: (v: string) => void;
    joining: boolean;
    onSubmit: (e: React.FormEvent) => void;
    onClose: () => void;
}) {
    return (
        <div className="modal-overlay" onClick={onClose}>
            <div className="modal-content p-8 max-w-md" onClick={(e) => e.stopPropagation()}>
                <div className="flex items-center justify-between mb-6">
                    <h2 className="text-2xl font-bold text-slate-900">Complete Registration</h2>
                    <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-lg">
                        <X className="w-6 h-6" />
                    </button>
                </div>

                <form onSubmit={onSubmit} className="space-y-6">
                    <div className="form-group">
                        <label className="label">Registration Token</label>
                        <input
                            type="text"
                            className="input font-mono"
                            value={joinToken}
                            onChange={(e) => setJoinToken(e.target.value)}
                            placeholder="Paste your registration token here"
                            required
                        />
                        <p className="text-xs text-slate-500 mt-1">
                            Enter the token received from the organization administrator.
                        </p>
                    </div>
                    <div className="flex space-x-3 pt-4">
                        <button
                            type="submit"
                            className="btn-primary flex-1"
                            disabled={joining || !joinToken}
                        >
                            {joining ? 'Joining...' : 'Join Organization'}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
}
