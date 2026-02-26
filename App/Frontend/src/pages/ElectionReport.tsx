import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { FileText, Download, ArrowLeft, Trophy, TrendingUp, Users, CheckCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { electionsApi } from '@/lib/api';

interface ReportRow {
    race_id: number;
    race_name: string;
    rank: number;
    candidate_name: string;
    votes_received: number;
    vote_percentage: number;
    is_winner: boolean;
    margin_from_next: number | null;
}

interface ElectionSummary {
    election_id: number;
    election_name: string;
    election_status: string;
    total_races: number;
    total_candidates: number;
    total_votes_cast: number;
    total_voters_participated: number;
}

export default function ElectionReport() {
    const { electionId } = useParams<{ electionId: string }>();
    const [report, setReport] = useState<ReportRow[]>([]);
    const [summary, setSummary] = useState<ElectionSummary | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        loadReportData();
    }, [electionId]);

    const loadReportData = async () => {
        if (!electionId) return;

        try {
            // Load report and summary in parallel
            const [reportData, summaryData] = await Promise.all([
                electionsApi.getReport(Number(electionId)),
                electionsApi.getSummary(Number(electionId))
            ]);

            setReport(reportData);
            setSummary(summaryData);
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to load election report');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const downloadReport = () => {
        if (!summary || !report.length) return;

        // Create CSV content
        const csvHeader = 'Race,Rank,Candidate,Votes,Percentage,Winner,Margin\n';
        const csvRows = report.map(row => 
            `"${row.race_name}",${row.rank},"${row.candidate_name}",${row.votes_received},${Number(row.vote_percentage || 0).toFixed(1)}%,${row.is_winner ? 'Yes' : 'No'},${row.margin_from_next ?? 'N/A'}`
        ).join('\n');
        
        const csvContent = csvHeader + csvRows;
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${summary.election_name.replace(/\s+/g, '_')}_Report.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
        
        toast.success('Report downloaded successfully!');
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="spinner w-16 h-16 mx-auto mb-4"></div>
                    <p className="text-slate-600 font-medium">Generating report...</p>
                </div>
            </div>
        );
    }

    if (!summary) {
        return (
            <div className="card empty-state">
                <FileText className="w-16 h-16 text-slate-300 mx-auto mb-4" />
                <h3 className="text-2xl font-bold text-slate-900 mb-3">Report Not Available</h3>
                <p className="text-slate-600">Unable to generate report for this election</p>
            </div>
        );
    }

    // Group report by race
    const raceGroups = report.reduce((acc, row) => {
        if (!acc[row.race_id]) {
            acc[row.race_id] = { race_name: row.race_name, candidates: [] };
        }
        acc[row.race_id].candidates.push(row);
        return acc;
    }, {} as Record<number, { race_name: string; candidates: ReportRow[] }>);

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <Link to="/elections" className="inline-flex items-center text-blue-600 hover:text-blue-700 mb-3">
                        <ArrowLeft className="w-4 h-4 mr-1" />
                        Back to Elections
                    </Link>
                    <h1 className="text-4xl font-black gradient-text mb-2">
                        <FileText className="inline w-10 h-10 mr-3" />
                        Election Report
                    </h1>
                    <p className="text-slate-600 text-lg">{summary.election_name}</p>
                </div>
                <button
                    onClick={downloadReport}
                    className="btn-primary flex items-center space-x-2"
                >
                    <Download className="w-5 h-5" />
                    <span>Download CSV</span>
                </button>
            </div>

            {/* Summary Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <div className="card bg-gradient-to-br from-blue-50 to-blue-100 border-blue-200">
                    <div className="flex items-center space-x-4">
                        <div className="p-3 bg-blue-600 rounded-xl">
                            <Trophy className="w-6 h-6 text-white" />
                        </div>
                        <div>
                            <p className="text-sm text-blue-700 font-medium">Total Races</p>
                            <p className="text-3xl font-black text-blue-900">{summary.total_races}</p>
                        </div>
                    </div>
                </div>

                <div className="card bg-gradient-to-br from-green-50 to-green-100 border-green-200">
                    <div className="flex items-center space-x-4">
                        <div className="p-3 bg-green-600 rounded-xl">
                            <Users className="w-6 h-6 text-white" />
                        </div>
                        <div>
                            <p className="text-sm text-green-700 font-medium">Total Candidates</p>
                            <p className="text-3xl font-black text-green-900">{summary.total_candidates}</p>
                        </div>
                    </div>
                </div>

                <div className="card bg-gradient-to-br from-purple-50 to-purple-100 border-purple-200">
                    <div className="flex items-center space-x-4">
                        <div className="p-3 bg-purple-600 rounded-xl">
                            <CheckCircle className="w-6 h-6 text-white" />
                        </div>
                        <div>
                            <p className="text-sm text-purple-700 font-medium">Total Votes</p>
                            <p className="text-3xl font-black text-purple-900">{summary.total_votes_cast}</p>
                        </div>
                    </div>
                </div>

                <div className="card bg-gradient-to-br from-amber-50 to-amber-100 border-amber-200">
                    <div className="flex items-center space-x-4">
                        <div className="p-3 bg-amber-600 rounded-xl">
                            <TrendingUp className="w-6 h-6 text-white" />
                        </div>
                        <div>
                            <p className="text-sm text-amber-700 font-medium">Voters Participated</p>
                            <p className="text-3xl font-black text-amber-900">{summary.total_voters_participated}</p>
                        </div>
                    </div>
                </div>
            </div>

            {/* Detailed Results by Race */}
            {Object.entries(raceGroups).map(([raceId, { race_name, candidates }]) => (
                <div key={raceId} className="card">
                    <h2 className="text-2xl font-bold text-slate-900 mb-4">{race_name}</h2>
                    
                    <div className="overflow-x-auto">
                        <table className="w-full">
                            <thead>
                                <tr className="border-b-2 border-slate-200">
                                    <th className="text-left py-3 px-4 text-sm font-bold text-slate-700">Rank</th>
                                    <th className="text-left py-3 px-4 text-sm font-bold text-slate-700">Candidate</th>
                                    <th className="text-right py-3 px-4 text-sm font-bold text-slate-700">Votes</th>
                                    <th className="text-right py-3 px-4 text-sm font-bold text-slate-700">Percentage</th>
                                    <th className="text-right py-3 px-4 text-sm font-bold text-slate-700">Margin</th>
                                    <th className="text-center py-3 px-4 text-sm font-bold text-slate-700">Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                {candidates.map((candidate) => (
                                    <tr 
                                        key={candidate.rank}
                                        className={`border-b border-slate-100 ${candidate.is_winner ? 'bg-green-50' : 'bg-white'}`}
                                    >
                                        <td className="py-3 px-4">
                                            <div className="flex items-center justify-center w-8 h-8 bg-slate-900 text-white rounded-full font-bold">
                                                {candidate.rank}
                                            </div>
                                        </td>
                                        <td className="py-3 px-4">
                                            <span className="font-semibold text-slate-900">{candidate.candidate_name}</span>
                                        </td>
                                        <td className="py-3 px-4 text-right">
                                            <span className="font-bold text-slate-900">{candidate.votes_received}</span>
                                        </td>
                                        <td className="py-3 px-4 text-right">
                                            <span className="text-slate-700">{Number(candidate.vote_percentage || 0).toFixed(1)}%</span>
                                        </td>
                                        <td className="py-3 px-4 text-right">
                                            <span className="text-slate-700">
                                                {candidate.margin_from_next !== null ? `+${candidate.margin_from_next}` : '—'}
                                            </span>
                                        </td>
                                        <td className="py-3 px-4 text-center">
                                            {candidate.is_winner && (
                                                <span className="px-3 py-1 bg-green-600 text-white text-xs font-bold rounded-full">
                                                    WINNER
                                                </span>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            ))}

            {/* Status Badge */}
            <div className="card bg-slate-50">
                <div className="flex items-center justify-between">
                    <div>
                        <p className="text-sm text-slate-600 mb-1">Election Status</p>
                        <p className="text-xl font-bold text-slate-900">{summary.election_status}</p>
                    </div>
                    <div className="text-right text-sm text-slate-500">
                        <p>Report generated on {new Date().toLocaleString()}</p>
                    </div>
                </div>
            </div>
        </div>
    );
}
