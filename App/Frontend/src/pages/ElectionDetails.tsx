import { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import {
    ArrowLeft,
    Plus,
    Trash2,
    Users,
    Trophy,
    X,
    CheckCircle,
    Clock,
    Calendar,
    Play,
    StopCircle
} from 'lucide-react';
import toast from 'react-hot-toast';
import { electionsApi, racesApi, candidatesApi } from '@/lib/api';
import { useAuthStore } from '@/store/authStore';
import type { ElectionWithDetails, Race, RaceFormData, CandidateFormData } from '@/types';

export default function ElectionDetails() {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const { currentOrganizationRole } = useAuthStore();
    const [election, setElection] = useState<ElectionWithDetails | null>(null);
    const [races, setRaces] = useState<Race[]>([]);
    const [loading, setLoading] = useState(true);
    const [showRaceModal, setShowRaceModal] = useState(false);
    const [showCandidateModal, setShowCandidateModal] = useState(false);
    const [showScheduleModal, setShowScheduleModal] = useState(false);
    const [selectedRace, setSelectedRace] = useState<Race | null>(null);
    const [submitting, setSubmitting] = useState(false);

    // Form states
    const [raceFormData, setRaceFormData] = useState<RaceFormData>({
        election_id: 0,
        race_name: '',
        description: '',
        max_votes_per_voter: 1,
    });

    const [candidateFormData, setCandidateFormData] = useState<CandidateFormData>({
        full_name: '',
        bio: '',
        manifesto: '',
    });

    const [scheduleData, setScheduleData] = useState({
        start_at: '',
        end_at: '',
    });
    const [showConfirmationModal, setShowConfirmationModal] = useState(false);

    useEffect(() => {
        if (id) {
            loadElectionDetails();
            loadRaces();
        }
    }, [id]);

    const loadElectionDetails = async () => {
        try {
            const data = await electionsApi.getById(Number(id));
            setElection(data);
        } catch (error: any) {
            toast.error('Failed to load election details');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const loadRaces = async () => {
        try {
            const data = await racesApi.listByElection(Number(id));
            setRaces(data);
        } catch (error: any) {
            console.error(error);
        }
    };

    const handleCreateRace = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            await racesApi.create({ ...raceFormData, election_id: Number(id) });
            toast.success('Race created successfully!');
            setShowRaceModal(false);
            setRaceFormData({ election_id: 0, race_name: '', description: '', max_votes_per_voter: 1 });
            loadRaces();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to create race');
        }
    };

    const handleDeleteRace = async (raceId: number) => {
        if (!confirm('Are you sure you want to delete this race?')) return;

        try {
            await racesApi.delete(raceId);
            toast.success('Race deleted successfully!');
            loadRaces();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to delete race');
        }
    };

    const handleAddCandidate = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!selectedRace) return;

        setSubmitting(true);
        try {
            await candidatesApi.add(selectedRace.race_id, candidateFormData);
            toast.success('Candidate added successfully!');
            setCandidateFormData({ full_name: '', bio: '', manifesto: '' });

            // Reload races to show the new candidate
            await loadRaces();

            // Close modal after data is refreshed
            setShowCandidateModal(false);
            setSelectedRace(null);
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to add candidate');
        } finally {
            setSubmitting(false);
        }
    };

    const handleRemoveCandidate = async (raceId: number, candidateId: number) => {
        if (!confirm('Are you sure you want to remove this candidate?')) return;

        try {
            await candidatesApi.remove(raceId, candidateId);
            toast.success('Candidate removed successfully!');
            loadRaces();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to remove candidate');
        }
    };

    const handleScheduleElection = () => {
        setShowScheduleModal(true);
    };

    const handleSaveSchedule = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!scheduleData.start_at || !scheduleData.end_at) {
            toast.error('Please set both start and end times');
            return;
        }

        try {
            // Use new schedule API which sets status to SCHEDULED
            await electionsApi.schedule(Number(id), scheduleData.start_at, scheduleData.end_at);
            toast.success('Election scheduled successfully! It will open automatically at the scheduled time.');
            setShowScheduleModal(false);
            loadElectionDetails();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to schedule election');
        }
    };

    const handleTriggerOpen = (e: React.FormEvent) => {
        e.preventDefault();
        setShowConfirmationModal(true);
    };

    const confirmOpenElection = async () => {
        try {
            // Update dates first if they are set
            if (scheduleData.start_at || scheduleData.end_at) {
                await electionsApi.update(Number(id), {
                    election_name: election!.election_name,
                    start_at: scheduleData.start_at || undefined,
                    end_at: scheduleData.end_at || undefined,
                });
            }

            await electionsApi.open(Number(id));
            toast.success('Election opened successfully!');
            setShowConfirmationModal(false);
            setShowScheduleModal(false);
            loadElectionDetails();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to open election');
        }
    };

    const handleCloseElection = async () => {
        if (!confirm('Are you sure you want to close this election? No more votes will be accepted after closing.')) {
            return;
        }

        try {
            await electionsApi.close(Number(id));
            toast.success('Election closed successfully!');
            loadElectionDetails();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to close election');
        }
    };

    const handleDeleteElection = async () => {
        if (!confirm('⚠️ Are you sure you want to DELETE this election? This action CANNOT be undone! All races, candidates, and votes will be permanently deleted.')) {
            return;
        }

        try {
            await electionsApi.delete(Number(id));
            toast.success('Election deleted successfully!');
            navigate('/dashboard/elections');
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to delete election');
        }
    };

    const openCandidateModal = (race: Race) => {
        setSelectedRace(race);
        setShowCandidateModal(true);
    };

    const isAdmin = currentOrganizationRole === 'OWNER' || currentOrganizationRole === 'ADMIN';
    // Allow editing in DRAFT and SCHEDULED status
    const canEdit = isAdmin && (election?.status === 'DRAFT' || election?.status === 'SCHEDULED');

    const getStatusConfig = (status: string) => {
        switch (status) {
            case 'OPEN':
                return {
                    color: 'bg-emerald-100 text-emerald-700 border-emerald-200',
                    icon: <CheckCircle className="w-5 h-5" />,
                };
            case 'DRAFT':
                return {
                    color: 'bg-amber-100 text-amber-700 border-amber-200',
                    icon: <Clock className="w-5 h-5" />,
                };
            case 'SCHEDULED':
                return {
                    color: 'bg-purple-100 text-purple-700 border-purple-200',
                    icon: <Calendar className="w-5 h-5" />,
                };
            case 'CLOSED':
                return {
                    color: 'bg-blue-100 text-blue-700 border-blue-200',
                    icon: <Trophy className="w-5 h-5" />,
                };
            default:
                return {
                    color: 'bg-slate-100 text-slate-700 border-slate-200',
                    icon: <Clock className="w-5 h-5" />,
                };
        }
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="spinner w-16 h-16 mx-auto mb-4"></div>
                    <p className="text-slate-600 font-medium">Loading election details...</p>
                </div>
            </div>
        );
    }

    if (!election) {
        return (
            <div className="card empty-state">
                <h3 className="text-2xl font-bold text-slate-900 mb-3">Election Not Found</h3>
                <Link to="/elections" className="btn-primary">
                    <ArrowLeft className="w-4 h-4 mr-2" />
                    Back to Elections
                </Link>
            </div>
        );
    }

    const statusConfig = getStatusConfig(election.status);

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center space-x-4">
                <Link to="/elections" className="p-2 hover:bg-white rounded-xl transition-colors">
                    <ArrowLeft className="w-6 h-6 text-slate-600" />
                </Link>
                <div className="flex-1">
                    <h1 className="text-4xl font-black gradient-text mb-2">{election.election_name}</h1>
                    <p className="text-slate-600">{election.description || 'No description'}</p>
                </div>
                <span className={`badge ${statusConfig.color} flex items-center space-x-2 text-base px-4 py-2`}>
                    {statusConfig.icon}
                    <span>{election.status}</span>
                </span>
            </div>

            {/* Action Buttons */}
            {isAdmin && (
                <div className="flex flex-wrap gap-3">
                    {election.status === 'DRAFT' && (
                        <>
                            <button onClick={() => setShowRaceModal(true)} className="btn-primary flex items-center">
                                <Plus className="w-4 h-4 mr-2" />
                                Add Race
                            </button>
                            <button onClick={handleScheduleElection} className="btn-success flex items-center">
                                <Play className="w-4 h-4 mr-2" />
                                Schedule & Open Election
                            </button>
                        </>
                    )}
                    {election.status === 'OPEN' && (
                        <button onClick={handleCloseElection} className="btn-danger flex items-center">
                            <StopCircle className="w-4 h-4 mr-2" />
                            Close Election
                        </button>
                    )}
                    {/* Delete button for DRAFT, SCHEDULED, or CLOSED elections */}
                    {(election.status === 'DRAFT' || election.status === 'SCHEDULED' || election.status === 'CLOSED') && (
                        <button
                            onClick={handleDeleteElection}
                            className="btn-secondary flex items-center bg-red-600 hover:bg-red-700 text-white border-red-600"
                        >
                            <Trash2 className="w-4 h-4 mr-2" />
                            Delete Election
                        </button>
                    )}
                </div>
            )}

            {/* Races List */}
            {races.length > 0 ? (
                <div className="space-y-6">
                    {races.map((race) => (
                        <div key={race.race_id} className="card">
                            <div className="flex items-start justify-between mb-4">
                                <div>
                                    <h3 className="text-2xl font-bold text-slate-900 mb-2">{race.race_name}</h3>
                                    <p className="text-slate-600 mb-2">{race.description || 'No description'}</p>
                                    <p className="text-sm text-slate-500">
                                        Max Votes Per Voter: <span className="font-semibold">{race.max_votes_per_voter}</span>
                                    </p>
                                </div>
                                {canEdit && (
                                    <div className="flex items-center space-x-2">
                                        <button
                                            onClick={() => openCandidateModal(race)}
                                            className="btn-primary flex items-center text-sm"
                                        >
                                            <Plus className="w-4 h-4 mr-1" />
                                            Add Candidate
                                        </button>
                                        <button
                                            onClick={() => handleDeleteRace(race.race_id)}
                                            className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                        >
                                            <Trash2 className="w-5 h-5" />
                                        </button>
                                    </div>
                                )}
                            </div>

                            {/* Candidates */}
                            {race.candidates && race.candidates.length > 0 ? (
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mt-4">
                                    {race.candidates.map((candidate) => (
                                        <div
                                            key={candidate.candidate_id}
                                            className="p-4 bg-gradient-to-br from-white to-slate-50 border-2 border-slate-200 rounded-xl hover:border-blue-500 hover:shadow-lg transition-all group"
                                        >
                                            <div className="flex items-start justify-between mb-3">
                                                <div className="flex items-center space-x-3">
                                                    <div className="w-12 h-12 rounded-full bg-gradient-to-r from-blue-600 to-indigo-600 flex items-center justify-center text-white font-bold text-lg">
                                                        {candidate.full_name.charAt(0)}
                                                    </div>
                                                    <div>
                                                        <h4 className="font-bold text-slate-900">{candidate.full_name}</h4>
                                                        {candidate.is_approved && (
                                                            <span className="text-xs text-emerald-600 flex items-center space-x-1">
                                                                <CheckCircle className="w-3 h-3" />
                                                                <span>Approved</span>
                                                            </span>
                                                        )}
                                                    </div>
                                                </div>
                                                {canEdit && (
                                                    <button
                                                        onClick={() => handleRemoveCandidate(race.race_id, candidate.candidate_id)}
                                                        className="p-1 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                                        title="Remove Candidate"
                                                    >
                                                        <Trash2 className="w-5 h-5" />
                                                    </button>
                                                )}
                                            </div>
                                            {candidate.bio && (
                                                <p className="text-sm text-slate-600 mb-2">{candidate.bio}</p>
                                            )}
                                            {candidate.manifesto && (
                                                <p className="text-xs text-slate-500 bg-slate-100 p-2 rounded-lg">
                                                    {candidate.manifesto}
                                                </p>
                                            )}
                                        </div>
                                    ))}
                                </div>
                            ) : (
                                <div className="text-center py-8 bg-slate-50 rounded-xl">
                                    <Users className="w-12 h-12 text-slate-400 mx-auto mb-3" />
                                    <p className="text-slate-600">No candidates yet</p>
                                </div>
                            )}
                        </div>
                    ))}
                </div>
            ) : (
                <div className="card empty-state">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                        <Trophy className="w-10 h-10 text-blue-600" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">No Races Yet</h3>
                    <p className="text-slate-600 mb-8">Add races (positions) to this election to get started</p>
                    {canEdit && (
                        <button onClick={() => setShowRaceModal(true)} className="btn-primary inline-flex items-center">
                            <Plus className="w-5 h-5 mr-2" />
                            Add Race
                        </button>
                    )}
                </div>
            )}

            {/* Create Race Modal */}
            {showRaceModal && (
                <div className="modal-overlay" onClick={() => setShowRaceModal(false)}>
                    <div className="modal-content p-8" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">Add Race</h2>
                            <button onClick={() => setShowRaceModal(false)} className="p-2 hover:bg-slate-100 rounded-lg">
                                <X className="w-6 h-6" />
                            </button>
                        </div>

                        <form onSubmit={handleCreateRace} className="space-y-6">
                            <div className="form-group">
                                <label className="label">Race Name (Position) *</label>
                                <input
                                    type="text"
                                    required
                                    value={raceFormData.race_name}
                                    onChange={(e) => setRaceFormData({ ...raceFormData, race_name: e.target.value })}
                                    className="input"
                                    placeholder="e.g., President, Vice President, Treasurer"
                                />
                            </div>

                            <div className="form-group">
                                <label className="label">Description</label>
                                <textarea
                                    value={raceFormData.description}
                                    onChange={(e) => setRaceFormData({ ...raceFormData, description: e.target.value })}
                                    className="input min-h-[80px]"
                                    placeholder="Describe this position..."
                                />
                            </div>

                            <div className="form-group">
                                <label className="label">Max Votes Per Voter *</label>
                                <input
                                    type="number"
                                    required
                                    min="1"
                                    value={raceFormData.max_votes_per_voter}
                                    onChange={(e) => setRaceFormData({ ...raceFormData, max_votes_per_voter: Number(e.target.value) })}
                                    className="input"
                                />
                                <p className="text-xs text-slate-500 mt-1">How many candidates a voter can select for this race</p>
                            </div>

                            <div className="flex space-x-3 pt-4">
                                <button type="submit" className="btn-primary flex-1">Add Race</button>
                                <button type="button" onClick={() => setShowRaceModal(false)} className="btn-secondary">
                                    Cancel
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Add Candidate Modal */}
            {showCandidateModal && selectedRace && (
                <div className="modal-overlay" onClick={() => setShowCandidateModal(false)}>
                    <div className="modal-content p-8" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">
                                Add Candidate to {selectedRace.race_name}
                            </h2>
                            <button onClick={() => setShowCandidateModal(false)} className="p-2 hover:bg-slate-100 rounded-lg">
                                <X className="w-6 h-6" />
                            </button>
                        </div>

                        <form onSubmit={handleAddCandidate} className="space-y-6">
                            <div className="form-group">
                                <label className="label">Full Name *</label>
                                <input
                                    type="text"
                                    required
                                    value={candidateFormData.full_name}
                                    onChange={(e) => setCandidateFormData({ ...candidateFormData, full_name: e.target.value })}
                                    className="input"
                                    placeholder="e.g., John Doe"
                                />
                            </div>

                            <div className="form-group">
                                <label className="label">Bio</label>
                                <textarea
                                    value={candidateFormData.bio}
                                    onChange={(e) => setCandidateFormData({ ...candidateFormData, bio: e.target.value })}
                                    className="input min-h-[80px]"
                                    placeholder="Brief biography..."
                                />
                            </div>

                            <div className="form-group">
                                <label className="label">Manifesto</label>
                                <textarea
                                    value={candidateFormData.manifesto}
                                    onChange={(e) => setCandidateFormData({ ...candidateFormData, manifesto: e.target.value })}
                                    className="input min-h-[100px]"
                                    placeholder="Campaign promises and goals..."
                                />
                            </div>


                            <div className="flex space-x-3 pt-4">
                                <button type="submit" className="btn-primary flex-1" disabled={submitting}>
                                    {submitting ? 'Adding...' : 'Add Candidate'}
                                </button>
                                <button type="button" onClick={() => setShowCandidateModal(false)} className="btn-secondary">
                                    Cancel
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Schedule Election Modal */}
            {showScheduleModal && (
                <div className="modal-overlay" onClick={() => setShowScheduleModal(false)}>
                    <div className="modal-content p-8" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">Schedule & Open Election</h2>
                            <button onClick={() => setShowScheduleModal(false)} className="p-2 hover:bg-slate-100 rounded-lg">
                                <X className="w-6 h-6" />
                            </button>
                        </div>

                        <form className="space-y-6">
                            <div className="alert-info">
                                <p className="text-sm">
                                    <strong>Note:</strong> You can save the schedule for later or open the election immediately.
                                </p>
                            </div>

                            <div className="form-group">
                                <label className="label">Start Date & Time (Optional)</label>
                                <input
                                    type="datetime-local"
                                    className="input"
                                    value={scheduleData.start_at}
                                    onChange={(e) => setScheduleData({ ...scheduleData, start_at: e.target.value })}
                                />
                                <p className="text-xs text-slate-500 mt-1">When should voting begin?</p>
                            </div>

                            <div className="form-group">
                                <label className="label">End Date & Time (Optional)</label>
                                <input
                                    type="datetime-local"
                                    className="input"
                                    value={scheduleData.end_at}
                                    onChange={(e) => setScheduleData({ ...scheduleData, end_at: e.target.value })}
                                />
                                <p className="text-xs text-slate-500 mt-1">When should voting end?</p>
                            </div>

                            <div className="flex flex-col space-y-3 pt-4">
                                <button
                                    type="button"
                                    onClick={handleSaveSchedule}
                                    className="btn-primary w-full flex items-center justify-center"
                                >
                                    <Clock className="w-4 h-4 mr-2" />
                                    Save Schedule
                                </button>

                                <div className="flex space-x-3">
                                    <button
                                        type="button"
                                        onClick={handleTriggerOpen}
                                        className="btn-success flex-1"
                                    >
                                        <Play className="w-4 h-4 mr-2 inline" />
                                        Open Election
                                    </button>
                                    <button type="button" onClick={() => setShowScheduleModal(false)} className="btn-secondary">
                                        Cancel
                                    </button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Confirmation Modal */}
            {showConfirmationModal && (
                <div className="modal-overlay" style={{ zIndex: 60 }}>
                    <div className="modal-content p-8 max-w-sm" onClick={(e) => e.stopPropagation()}>
                        <div className="text-center">
                            <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100 mb-4">
                                <Play className="h-6 w-6 text-green-600" />
                            </div>
                            <h3 className="text-lg font-medium text-slate-900 mb-2">Confirm Open Election</h3>
                            <p className="text-sm text-slate-500 mb-6">
                                Are you sure you want to open this election? Voters will be able to start voting immediately according to the schedule.
                            </p>
                            <div className="flex space-x-3">
                                <button
                                    onClick={confirmOpenElection}
                                    className="btn-success flex-1"
                                >
                                    Yes, Open It
                                </button>
                                <button
                                    onClick={() => setShowConfirmationModal(false)}
                                    className="btn-secondary flex-1"
                                >
                                    Cancel
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
