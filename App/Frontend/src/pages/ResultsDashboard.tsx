import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { Trophy, TrendingUp, ArrowLeft, Crown, Medal, Award, CheckCircle, Clock } from 'lucide-react';
import toast from 'react-hot-toast';
import { votingApi } from '@/lib/api';

interface CandidateResult {
    candidate_id: number;
    display_name: string;
    vote_count: number;
}

interface RaceResult {
    race_id: number;
    race_name: string;
    description?: string;
    max_votes_per_voter: number;
    max_winners: number;
    results: CandidateResult[];
    total_votes: number;
}

interface ElectionResults {
    election: {
        election_id: number;
        election_name: string;
        description?: string;
        status: string;
    };
    races: RaceResult[];
}

export default function ResultsDashboard() {
    const { electionId } = useParams<{ electionId: string }>();
    const [results, setResults] = useState<ElectionResults | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        loadResults();
        // Auto-refresh every 10 seconds for live results
        const interval = setInterval(loadResults, 10000);
        return () => clearInterval(interval);
    }, [electionId]);

    const loadResults = async () => {
        if (!electionId) return;

        try {
            const data = await votingApi.getElectionResults(Number(electionId));
            setResults(data);
        } catch (error: any) {
            toast.error('Failed to load results');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const getPositionIcon = (position: number) => {
        if (position === 1) return <Crown className="w-6 h-6 text-yellow-500" />;
        if (position === 2) return <Medal className="w-6 h-6 text-slate-400" />;
        if (position === 3) return <Award className="w-6 h-6 text-amber-600" />;
        return null;
    };

    const getPositionColor = (position: number, maxWinners: number) => {
        if (position <= maxWinners) {
            if (position === 1) return 'from-yellow-50 to-amber-50 border-yellow-300';
            return 'from-green-50 to-emerald-50 border-green-300';
        }
        return 'from-white to-slate-50 border-slate-200';
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="spinner w-16 h-16 mx-auto mb-4"></div>
                    <p className="text-slate-600 font-medium">Loading results...</p>
                </div>
            </div>
        );
    }

    if (!results) {
        return (
            <div className="card empty-state">
                <Trophy className="w-16 h-16 text-slate-300 mx-auto mb-4" />
                <h3 className="text-2xl font-bold text-slate-900 mb-3">No Results Found</h3>
                <p className="text-slate-600">Unable to load election results</p>
            </div>
        );
    }

    const isLive = results.election.status === 'OPEN';
    const isClosed = results.election.status === 'CLOSED';

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <Link to="/elections" className="inline-flex items-center text-blue-600 hover:text-blue-700 mb-3">
                        <ArrowLeft className="w-4 h-4 mr-1" />
                        Back to Elections
                    </Link>
                    <h1 className="text-4xl font-black gradient-text mb-2">{results.election.election_name}</h1>
                    <p className="text-slate-600">{results.election.description}</p>
                </div>
                <div className="text-right">
                    {isLive && (
                        <div className="inline-flex items-center space-x-2 bg-green-100 text-green-700 px-4 py-2 rounded-full font-bold">
                            <span className="w-2 h-2 bg-green-600 rounded-full animate-pulse"></span>
                            <span>LIVE RESULTS</span>
                        </div>
                    )}
                    {isClosed && (
                        <div className="inline-flex items-center space-x-2 bg-blue-100 text-blue-700 px-4 py-2 rounded-full font-bold">
                            <CheckCircle className="w-5 h-5" />
                            <span>FINAL RESULTS</span>
                        </div>
                    )}
                </div>
            </div>

            {/* Results for each race */}
            {results.races.map((race) => (
                <div key={race.race_id} className="card">
                    <div className="flex items-center justify-between mb-6">
                        <div>
                            <h2 className="text-2xl font-bold text-slate-900 mb-1">{race.race_name}</h2>
                            {race.description && <p className="text-slate-600">{race.description}</p>}
                        </div>
                        <div className="text-right">
                            <p className="text-sm text-slate-500">Total Votes</p>
                            <p className="text-3xl font-black text-blue-600">{race.total_votes}</p>
                        </div>
                    </div>

                    {race.results.length === 0 ? (
                        <div className="text-center py-8 bg-slate-50 rounded-xl">
                            <Clock className="w-12 h-12 text-slate-300 mx-auto mb-3" />
                            <p className="text-slate-600">No votes cast yet</p>
                        </div>
                    ) : (
                        <div className="space-y-3">
                            {race.results.map((candidate, index) => {
                                const position = index + 1;
                                const percentage = race.total_votes > 0
                                    ? ((candidate.vote_count / race.total_votes) * 100).toFixed(1)
                                    : '0.0';
                                const isWinner = position <= race.max_winners;

                                return (
                                    <div
                                        key={candidate.candidate_id}
                                        className={`relative p-5 bg-gradient-to-r ${getPositionColor(position, race.max_winners)} border-2 rounded-2xl transition-all hover:shadow-lg`}
                                    >
                                        <div className="flex items-center justify-between">
                                            <div className="flex items-center space-x-4 flex-1">
                                                <div className="flex items-center justify-center w-12 h-12 bg-white rounded-full border-2 border-slate-200 font-bold text-lg">
                                                    {getPositionIcon(position) || position}
                                                </div>
                                                <div className="flex-1">
                                                    <div className="flex items-center space-x-3">
                                                        <h3 className="text-xl font-bold text-slate-900">
                                                            {candidate.display_name}
                                                        </h3>
                                                        {isWinner && isClosed && (
                                                            <span className="px-3 py-1 bg-green-600 text-white text-xs font-bold rounded-full">
                                                                WINNER
                                                            </span>
                                                        )}
                                                        {isWinner && isLive && (
                                                            <span className="px-3 py-1 bg-blue-600 text-white text-xs font-bold rounded-full">
                                                                LEADING
                                                            </span>
                                                        )}
                                                    </div>
                                                    <div className="mt-2 bg-slate-200 rounded-full h-3 overflow-hidden">
                                                        <div
                                                            className={`h-full transition-all duration-500 ${isWinner ? 'bg-gradient-to-r from-green-500 to-emerald-600' : 'bg-slate-400'
                                                                }`}
                                                            style={{ width: `${percentage}%` }}
                                                        ></div>
                                                    </div>
                                                </div>
                                            </div>
                                            <div className="text-right ml-6">
                                                <p className="text-3xl font-black text-slate-900">{candidate.vote_count}</p>
                                                <p className="text-sm font-semibold text-slate-600">{percentage}%</p>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    )}
                </div>
            ))}

            {isLive && (
                <div className="card bg-blue-50 border-blue-200">
                    <div className="flex items-start space-x-4">
                        <TrendingUp className="w-6 h-6 text-blue-600 flex-shrink-0 mt-1" />
                        <div>
                            <h3 className="font-bold text-blue-900 mb-1">Live Results</h3>
                            <p className="text-sm text-blue-700">
                                Results are updating in real-time as votes are cast. The final winners will be determined when the election closes.
                            </p>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
