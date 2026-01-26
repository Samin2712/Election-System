import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
    BarChart3,
    Plus,
    Calendar,
    Clock,
    CheckCircle,
    XCircle,
    Trophy,
    ArrowRight,
    X,
    Play,
    StopCircle,
    Search,
    Filter
} from 'lucide-react';
import toast from 'react-hot-toast';
import { electionsApi } from '@/lib/api';
import { useAuthStore } from '@/store/authStore';
import type { Election } from '@/types';

export default function Elections() {
    const { currentOrganization, currentOrganizationRole } = useAuthStore();
    const [elections, setElections] = useState<Election[]>([]);
    const [loading, setLoading] = useState(true);
    const [showCreateModal, setShowCreateModal] = useState(false);
    const [searchTerm, setSearchTerm] = useState('');
    const [statusFilter, setStatusFilter] = useState<string>('ALL');

    // Form state
    const [formData, setFormData] = useState({
        election_name: '',
        description: '',
        start_datetime: '',
        end_datetime: '',
    });

    useEffect(() => {
        if (currentOrganization) {
            loadElections();
        }
    }, [currentOrganization]);

    const loadElections = async () => {
        if (!currentOrganization) return;

        setLoading(true);
        try {
            const data = await electionsApi.list(currentOrganization.organization_id);
            setElections(data);
        } catch (error: any) {
            toast.error('Failed to load elections');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const handleCreate = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!currentOrganization) {
            toast.error('Please select an organization first');
            return;
        }

        try {
            await electionsApi.create({
                organization_id: currentOrganization.organization_id,
                election_name: formData.election_name,
                description: formData.description || undefined,
            });
            toast.success('Election created successfully!');
            setShowCreateModal(false);
            setFormData({ election_name: '', description: '', start_datetime: '', end_datetime: '' });
            loadElections();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to create election');
        }
    };

    const handleOpenElection = async (electionId: number) => {
        try {
            await electionsApi.open(electionId);
            toast.success('Election opened successfully!');
            loadElections();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to open election');
        }
    };

    const handleCloseElection = async (electionId: number) => {
        try {
            await electionsApi.close(electionId);
            toast.success('Election closed successfully!');
            loadElections();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to close election');
        }
    };

    const getStatusConfig = (status: string) => {
        switch (status) {
            case 'OPEN':
                return {
                    color: 'bg-emerald-100 text-emerald-700 border-emerald-200',
                    icon: <CheckCircle className="w-4 h-4" />,
                    label: 'Open',
                };
            case 'DRAFT':
                return {
                    color: 'bg-amber-100 text-amber-700 border-amber-200',
                    icon: <Clock className="w-4 h-4" />,
                    label: 'Draft',
                };
            case 'CLOSED':
                return {
                    color: 'bg-blue-100 text-blue-700 border-blue-200',
                    icon: <Trophy className="w-4 h-4" />,
                    label: 'Closed',
                };
            default:
                return {
                    color: 'bg-slate-100 text-slate-700 border-slate-200',
                    icon: <Clock className="w-4 h-4" />,
                    label: status,
                };
        }
    };

    const isAdmin = currentOrganizationRole === 'OWNER' || currentOrganizationRole === 'ADMIN';

    const filteredElections = elections.filter(election => {
        const matchesSearch = election.election_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
            election.description?.toLowerCase().includes(searchTerm.toLowerCase());
        const matchesStatus = statusFilter === 'ALL' || election.status === statusFilter;
        return matchesSearch && matchesStatus;
    });

    if (!currentOrganization) {
        return (
            <div className="card empty-state">
                <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                    <BarChart3 className="w-10 h-10 text-blue-600" />
                </div>
                <h3 className="text-2xl font-bold text-slate-900 mb-3">
                    No Organization Selected
                </h3>
                <p className="text-slate-600">
                    Please select an organization from the header to view elections
                </p>
            </div>
        );
    }

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="spinner w-16 h-16 mx-auto mb-4"></div>
                    <p className="text-slate-600 font-medium">Loading elections...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                <div>
                    <h1 className="text-4xl font-black gradient-text mb-2">Elections</h1>
                    <p className="text-slate-600">
                        Managing elections for <span className="font-semibold">{currentOrganization.organization_name}</span>
                    </p>
                </div>
                {isAdmin && (
                    <button
                        onClick={() => setShowCreateModal(true)}
                        className="btn-primary flex items-center"
                    >
                        <Plus className="w-5 h-5 mr-2" />
                        Create Election
                    </button>
                )}
            </div>

            {/* Filters */}
            <div className="card">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {/* Search */}
                    <div className="relative">
                        <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-slate-400" />
                        <input
                            type="text"
                            placeholder="Search elections..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="input pl-12"
                        />
                    </div>

                    {/* Status Filter */}
                    <div className="relative">
                        <Filter className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-slate-400" />
                        <select
                            value={statusFilter}
                            onChange={(e) => setStatusFilter(e.target.value)}
                            className="input pl-12"
                        >
                            <option value="ALL">All Statuses</option>
                            <option value="DRAFT">Draft</option>
                            <option value="OPEN">Open</option>
                            <option value="CLOSED">Closed</option>
                        </select>
                    </div>
                </div>
            </div>

            {/* Elections List */}
            {filteredElections.length > 0 ? (
                <div className="space-y-4">
                    {filteredElections.map((election) => {
                        const statusConfig = getStatusConfig(election.status);
                        return (
                            <div
                                key={election.election_id}
                                className="card hover-lift"
                            >
                                <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                                    <div className="flex-1">
                                        <div className="flex items-start justify-between mb-3">
                                            <div>
                                                <Link
                                                    to={`/elections/${election.election_id}`}
                                                    className="text-2xl font-bold text-slate-900 hover:text-blue-600 transition-colors"
                                                >
                                                    {election.election_name}
                                                </Link>
                                                <p className="text-slate-600 mt-2">
                                                    {election.description || 'No description provided'}
                                                </p>
                                            </div>
                                            <span className={`badge ${statusConfig.color} flex items-center space-x-1 ml-4`}>
                                                {statusConfig.icon}
                                                <span>{statusConfig.label}</span>
                                            </span>
                                        </div>

                                        <div className="flex flex-wrap items-center gap-4 text-sm text-slate-500">
                                            <span className="flex items-center space-x-1">
                                                <Calendar className="w-4 h-4" />
                                                <span>Created {new Date(election.created_at).toLocaleDateString()}</span>
                                            </span>
                                            {election.start_datetime && (
                                                <span className="flex items-center space-x-1">
                                                    <Play className="w-4 h-4" />
                                                    <span>Starts {new Date(election.start_datetime).toLocaleDateString()}</span>
                                                </span>
                                            )}
                                            {election.end_datetime && (
                                                <span className="flex items-center space-x-1">
                                                    <StopCircle className="w-4 h-4" />
                                                    <span>Ends {new Date(election.end_datetime).toLocaleDateString()}</span>
                                                </span>
                                            )}
                                        </div>
                                    </div>

                                    <div className="flex items-center space-x-3">
                                        {isAdmin && election.status === 'DRAFT' && (
                                            <button
                                                onClick={() => handleOpenElection(election.election_id)}
                                                className="btn-success flex items-center"
                                            >
                                                <Play className="w-4 h-4 mr-2" />
                                                Open Election
                                            </button>
                                        )}
                                        {isAdmin && election.status === 'OPEN' && (
                                            <button
                                                onClick={() => handleCloseElection(election.election_id)}
                                                className="btn-danger flex items-center"
                                            >
                                                <StopCircle className="w-4 h-4 mr-2" />
                                                Close Election
                                            </button>
                                        )}
                                        {(election.status === 'OPEN' || election.status === 'CLOSED') && (
                                            <Link
                                                to={`/results/${election.election_id}`}
                                                className="btn-primary flex items-center"
                                            >
                                                <Trophy className="w-4 h-4 mr-2" />
                                                View Results
                                            </Link>
                                        )}
                                        <Link
                                            to={`/elections/${election.election_id}`}
                                            className="btn-secondary flex items-center"
                                        >
                                            View Details
                                            <ArrowRight className="w-4 h-4 ml-2" />
                                        </Link>
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            ) : (
                <div className="card empty-state">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                        <BarChart3 className="w-10 h-10 text-blue-600" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">
                        {searchTerm || statusFilter !== 'ALL' ? 'No elections found' : 'No Elections Yet'}
                    </h3>
                    <p className="text-slate-600 mb-8">
                        {searchTerm || statusFilter !== 'ALL'
                            ? 'Try adjusting your search or filters'
                            : 'Create your first election to get started'}
                    </p>
                    {isAdmin && !searchTerm && statusFilter === 'ALL' && (
                        <button onClick={() => setShowCreateModal(true)} className="btn-primary inline-flex items-center">
                            <Plus className="w-5 h-5 mr-2" />
                            Create Election
                        </button>
                    )}
                </div>
            )}

            {/* Create Modal */}
            {showCreateModal && (
                <div className="modal-overlay" onClick={() => setShowCreateModal(false)}>
                    <div className="modal-content p-8" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">Create Election</h2>
                            <button
                                onClick={() => setShowCreateModal(false)}
                                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
                            >
                                <X className="w-6 h-6" />
                            </button>
                        </div>

                        <form onSubmit={handleCreate} className="space-y-6">
                            <div className="form-group">
                                <label className="label">Election Name *</label>
                                <input
                                    type="text"
                                    required
                                    value={formData.election_name}
                                    onChange={(e) => setFormData({ ...formData, election_name: e.target.value })}
                                    className="input"
                                    placeholder="e.g., Student Council Elections 2024"
                                />
                            </div>

                            <div className="form-group">
                                <label className="label">Description</label>
                                <textarea
                                    value={formData.description}
                                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                    className="input min-h-[100px]"
                                    placeholder="Describe the purpose and scope of this election..."
                                />
                            </div>

                            <div className="alert-info">
                                <p className="text-sm">
                                    <strong>Note:</strong> The election will be created in DRAFT status. You can add races and candidates before opening it for voting.
                                </p>
                            </div>

                            <div className="flex space-x-3 pt-4">
                                <button type="submit" className="btn-primary flex-1">
                                    Create Election
                                </button>
                                <button
                                    type="button"
                                    onClick={() => setShowCreateModal(false)}
                                    className="btn-secondary"
                                >
                                    Cancel
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}
