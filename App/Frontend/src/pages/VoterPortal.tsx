import { useState, useEffect } from 'react';
import { Vote, CheckCircle, Clock, AlertCircle, Trophy, Sparkles } from 'lucide-react';
import toast from 'react-hot-toast';
import { votingApi, electionsApi, racesApi } from '@/lib/api';
import { useAuthStore } from '@/store/authStore';
import type { VoterStatusResponse, Election, Race, VoteData } from '@/types';

export default function VoterPortal() {
    const { currentOrganization } = useAuthStore();
    const [voterStatus, setVoterStatus] = useState<VoterStatusResponse | null>(null);
    const [elections, setElections] = useState<Election[]>([]);
    const [selectedElection, setSelectedElection] = useState<Election | null>(null);
    const [races, setRaces] = useState<Race[]>([]);
    const [votes, setVotes] = useState<{ [raceId: number]: number[] }>({});
    const [loading, setLoading] = useState(true);
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        if (currentOrganization) {
            loadVoterData();
        }
    }, [currentOrganization]);

    useEffect(() => {
        if (selectedElection) {
            loadRaces();
        }
    }, [selectedElection]);

    const loadVoterData = async () => {
        if (!currentOrganization) return;

        setLoading(true);
        try {
            // Check voter status
            try {
                const status = await votingApi.getStatus(currentOrganization.organization_id);
                setVoterStatus(status);
            } catch (error) {
                setVoterStatus(null);
            }

            // Load open elections
            const electionsData = await electionsApi.list(currentOrganization.organization_id);
            const openElections = electionsData.filter(e => e.status === 'OPEN');
            setElections(openElections);

            if (openElections.length > 0) {
                setSelectedElection(openElections[0]);
            }
        } catch (error: any) {
            toast.error('Failed to load voter data');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const loadRaces = async () => {
        if (!selectedElection) return;

        try {
            const racesData = await racesApi.listByElection(selectedElection.election_id);
            setRaces(racesData);
        } catch (error: any) {
            toast.error('Failed to load races');
            console.error(error);
        }
    };



    const handleVoteSelection = (raceId: number, candidateId: number, maxVotes: number) => {
        setVotes(prev => {
            const currentVotes = prev[raceId] || [];
            const isAlreadySelected = currentVotes.includes(candidateId);

            if (isAlreadySelected) {
                // Remove the candidate
                return {
                    ...prev,
                    [raceId]: currentVotes.filter(id => id !== candidateId)
                };
            } else {
                // Add the candidate if not at max
                if (currentVotes.length >= maxVotes) {
                    toast.error(`You can only select up to ${maxVotes} candidate${maxVotes > 1 ? 's' : ''} for this race`);
                    return prev;
                }
                return {
                    ...prev,
                    [raceId]: [...currentVotes, candidateId]
                };
            }
        });
    };

    const handleSubmitVotes = async () => {
        if (!selectedElection || !voterStatus?.voter) return;

        const voteEntries = Object.entries(votes);
        if (voteEntries.length === 0) {
            toast.error('Please select at least one candidate');
            return;
        }

        setSubmitting(true);
        try {
            // Submit all votes
            for (const [raceId, candidateIds] of voteEntries) {
                for (const candidateId of candidateIds) {
                    const voteData: VoteData = {
                        election_id: selectedElection.election_id,
                        race_id: Number(raceId),
                        candidate_id: candidateId
                    };
                    await votingApi.castVote(voteData);
                }
            }

            const totalVotes = voteEntries.reduce((sum, [_, ids]) => sum + ids.length, 0);
            toast.success(`${totalVotes} vote${totalVotes > 1 ? 's' : ''} submitted successfully!`);
            setVotes({});
            loadVoterData();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to submit votes');
        } finally {
            setSubmitting(false);
        }
    };

    if (!currentOrganization) {
        return (
            <div className="card empty-state">
                <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                    <Vote className="w-10 h-10 text-blue-600" />
                </div>
                <h3 className="text-2xl font-bold text-slate-900 mb-3">No Organization Selected</h3>
                <p className="text-slate-600">Please select an organization from the header to vote</p>
            </div>
        );
    }

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="spinner w-16 h-16 mx-auto mb-4"></div>
                    <p className="text-slate-600 font-medium">Loading voter portal...</p>
                </div>
            </div>
        );
    }

    // Not registered as voter or suspended
    if (!voterStatus?.registered) {
        return (
            <div className="space-y-6">
                <h1 className="text-4xl font-black gradient-text mb-2">Voter Portal</h1>
                <div className="card text-center py-12">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-slate-100 rounded-full mb-6">
                        <AlertCircle className="w-10 h-10 text-slate-400" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">Registration Not Active</h3>
                    <p className="text-slate-600 max-w-md mx-auto">
                        Your voter registration in <span className="font-semibold">{currentOrganization.organization_name}</span> is currently not active or has been suspended.
                    </p>
                </div>
            </div>
        );
    }

    // Registered but not approved
    if (!voterStatus.voter?.is_approved) {
        return (
            <div className="space-y-6">
                <h1 className="text-4xl font-black gradient-text mb-2">Voter Portal</h1>

                <div className="card text-center py-12">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-amber-100 to-orange-100 rounded-full mb-6">
                        <Clock className="w-10 h-10 text-amber-600 animate-pulse" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">
                        Approval Pending
                    </h3>
                    <p className="text-slate-600 mb-4 max-w-md mx-auto">
                        Your voter registration is pending approval from an administrator
                    </p>
                    <div className="alert-info inline-block">
                        <p className="text-sm">You'll be able to vote once your registration is approved</p>
                    </div>
                </div>
            </div>
        );
    }

    // No open elections
    if (elections.length === 0) {
        return (
            <div className="space-y-6">
                <h1 className="text-4xl font-black gradient-text mb-2">Voter Portal</h1>

                <div className="card empty-state">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                        <Trophy className="w-10 h-10 text-blue-600" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">
                        No Active Elections
                    </h3>
                    <p className="text-slate-600">
                        There are currently no open elections in {currentOrganization.organization_name}
                    </p>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="relative overflow-hidden gradient-bg rounded-3xl p-8 text-white shadow-2xl">
                <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGRlZnM+PHBhdHRlcm4gaWQ9ImdyaWQiIHdpZHRoPSI2MCIgaGVpZ2h0PSI2MCIgcGF0dGVyblVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+PHBhdGggZD0iTSAxMCAwIEwgMCAwIDAgMTAiIGZpbGw9Im5vbmUiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS1vcGFjaXR5PSIwLjEiIHN0cm9rZS13aWR0aD0iMSIvPjwvcGF0dGVybj48L2RlZnM+PHJlY3Qgd2lkdGg9IjEwMCUiIGhlaWdodD0iMTAwJSIgZmlsbD0idXJsKCNncmlkKSIvPjwvc3ZnPg==')] opacity-20"></div>
                <div className="relative z-10">
                    <div className="flex items-center space-x-3 mb-3">
                        <Sparkles className="w-8 h-8" />
                        <h1 className="text-4xl font-black">Cast Your Vote</h1>
                    </div>
                    <p className="text-blue-100 text-lg">
                        Voting in: <span className="font-bold">{selectedElection?.election_name}</span>
                    </p>
                </div>
            </div>

            {/* Election Selector */}
            {elections.length > 1 && (
                <div className="card">
                    <label className="label">Select Election</label>
                    <select
                        value={selectedElection?.election_id || ''}
                        onChange={(e) => {
                            const election = elections.find(el => el.election_id === Number(e.target.value));
                            setSelectedElection(election || null);
                            setVotes({});
                        }}
                        className="input"
                    >
                        {elections.map(election => (
                            <option key={election.election_id} value={election.election_id}>
                                {election.election_name}
                            </option>
                        ))}
                    </select>
                </div>
            )}

            {/* Races and Candidates */}
            {races.length > 0 ? (
                <div className="space-y-6">
                    {races.map((race) => (
                        <div key={race.race_id} className="card">
                            <div className="mb-6">
                                <h3 className="text-2xl font-bold text-slate-900 mb-2">{race.race_name}</h3>
                                <p className="text-slate-600">{race.description || 'Select your preferred candidate'}</p>
                                <p className="text-sm text-slate-500 mt-1">
                                    {race.max_winners === 1 ? 'Select one candidate' : `Select up to ${race.max_winners} candidates`}
                                </p>
                            </div>

                            {race.candidates && race.candidates.length > 0 ? (
                                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                                    {race.candidates.map((candidate) => {
                                        const currentVotes = votes[race.race_id] || [];
                                        const isSelected = currentVotes.includes(candidate.candidate_id);
                                        return (
                                            <button
                                                key={candidate.candidate_id}
                                                onClick={() => handleVoteSelection(race.race_id, candidate.candidate_id, race.max_votes_per_voter)}
                                                className={`p-6 text-left rounded-2xl border-2 transition-all duration-300 ${isSelected
                                                    ? 'border-blue-600 bg-gradient-to-br from-blue-50 to-indigo-50 shadow-xl scale-105'
                                                    : 'border-slate-200 bg-white hover:border-blue-400 hover:shadow-lg'
                                                    }`}
                                            >
                                                <div className="flex items-start space-x-4 mb-4">
                                                    <div className={`w-16 h-16 rounded-full flex items-center justify-center text-white font-bold text-2xl ${isSelected
                                                        ? 'bg-gradient-to-r from-blue-600 to-indigo-600 shadow-lg'
                                                        : 'bg-gradient-to-r from-slate-400 to-slate-500'
                                                        }`}>
                                                        {candidate.full_name.charAt(0)}
                                                    </div>
                                                    <div className="flex-1">
                                                        <h4 className="font-bold text-lg text-slate-900 mb-1">
                                                            {candidate.full_name}
                                                        </h4>
                                                        {isSelected && (
                                                            <span className="inline-flex items-center space-x-1 text-sm text-blue-600 font-semibold">
                                                                <CheckCircle className="w-4 h-4" />
                                                                <span>Selected</span>
                                                            </span>
                                                        )}
                                                    </div>
                                                </div>
                                                {candidate.bio && (
                                                    <p className="text-sm text-slate-600 mb-3">{candidate.bio}</p>
                                                )}
                                                {candidate.manifesto && (
                                                    <div className="bg-slate-100 p-3 rounded-lg">
                                                        <p className="text-xs font-semibold text-slate-700 mb-1">Manifesto:</p>
                                                        <p className="text-xs text-slate-600">{candidate.manifesto}</p>
                                                    </div>
                                                )}
                                            </button>
                                        );
                                    })}
                                </div>
                            ) : (
                                <div className="text-center py-8 bg-slate-50 rounded-xl">
                                    <AlertCircle className="w-12 h-12 text-slate-400 mx-auto mb-3" />
                                    <p className="text-slate-600">No candidates available for this race</p>
                                </div>
                            )}
                        </div>
                    ))}

                    {/* Submit Button */}
                    <div className="card bg-gradient-to-r from-blue-50 to-indigo-50 border-2 border-blue-200">
                        <div className="flex items-center justify-between">
                            <div>
                                <h3 className="font-bold text-slate-900 mb-1">Ready to submit your votes?</h3>
                                <p className="text-sm text-slate-600">
                                    You've selected {Object.values(votes).reduce((sum, ids) => sum + ids.length, 0)} candidate{Object.values(votes).reduce((sum, ids) => sum + ids.length, 0) !== 1 ? 's' : ''} across {Object.keys(votes).length} race{Object.keys(votes).length !== 1 ? 's' : ''}
                                </p>
                            </div>
                            <button
                                onClick={handleSubmitVotes}
                                disabled={submitting || Object.keys(votes).length === 0}
                                className="btn-primary flex items-center"
                            >
                                {submitting ? (
                                    <>
                                        <div className="spinner w-5 h-5 mr-2"></div>
                                        Submitting...
                                    </>
                                ) : (
                                    <>
                                        <Vote className="w-5 h-5 mr-2" />
                                        Submit Votes
                                    </>
                                )}
                            </button>
                        </div>
                    </div>
                </div>
            ) : (
                <div className="card empty-state">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                        <Trophy className="w-10 h-10 text-blue-600" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">No Races Available</h3>
                    <p className="text-slate-600">This election doesn't have any races yet</p>
                </div>
            )}
        </div>
    );
}
