import { useState, useEffect } from 'react';
import {
    Calendar,
    Clock,
    Building2,
    Mail,
    Shield
} from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore } from '@/store/authStore';
import { organizationsApi, electionsApi } from '@/lib/api';
import type { UserOrganization, Election } from '@/types';

export default function UserProfile() {
    const { user } = useAuthStore();
    const [loading, setLoading] = useState(true);
    const [organizations, setOrganizations] = useState<UserOrganization[]>([]);
    const [elections, setElections] = useState<Election[]>([]);

    useEffect(() => {
        loadProfileData();
    }, []);

    const loadProfileData = async () => {
        setLoading(true);
        try {
            // Load connected organizations
            const orgsData = await organizationsApi.getUserOrganizations();
            setOrganizations(orgsData);

            // Load elections for all organizations
            const allElections: Election[] = [];
            for (const org of orgsData) {
                try {
                    const orgElections = await electionsApi.list(org.organization_id);
                    allElections.push(...orgElections.map(e => ({
                        ...e,
                        organization_name: org.organization_name
                    })));
                } catch (error) {
                    console.error(`Failed to load elections for org ${org.organization_id}`);
                }
            }
            setElections(allElections);

        } catch (error: any) {
            toast.error('Failed to load profile data');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="spinner w-12 h-12"></div>
            </div>
        );
    }

    return (
        <div className="space-y-8">
            {/* Header */}
            <div className="bg-white rounded-3xl p-8 shadow-sm border border-slate-200">
                <div className="flex flex-col md:flex-row items-center md:items-start space-y-4 md:space-y-0 md:space-x-6">
                    <div className="w-24 h-24 rounded-full bg-gradient-to-r from-blue-600 to-indigo-600 flex items-center justify-center text-4xl text-white font-bold shadow-lg">
                        {user?.username?.charAt(0).toUpperCase()}
                    </div>
                    <div className="flex-1 text-center md:text-left">
                        <h1 className="text-3xl font-bold text-slate-900 mb-2">{user?.username}</h1>
                        <div className="flexflex-col sm:flex-row items-center justify-center md:justify-start space-y-2 sm:space-y-0 sm:space-x-6 text-slate-600">
                            <div className="flex items-center space-x-2">
                                <Mail className="w-4 h-4" />
                                <span>{user?.email}</span>
                            </div>
                            <div className="flex items-center space-x-2">
                                <Shield className="w-4 h-4" />
                                <span>Member</span>
                            </div>
                        </div>
                    </div>
                    <div className="flex space-x-4">
                        <div className="text-center px-6 py-3 bg-slate-50 rounded-2xl border border-slate-100">
                            <p className="text-2xl font-bold text-slate-900">{organizations.length}</p>
                            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Organizations</p>
                        </div>
                        <div className="text-center px-6 py-3 bg-slate-50 rounded-2xl border border-slate-100">
                            <p className="text-2xl font-bold text-slate-900">{elections.length}</p>
                            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Elections</p>
                        </div>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {/* Organizations */}
                <div className="card">
                    <div className="flex items-center space-x-3 mb-6">
                        <div className="p-2 bg-blue-100 rounded-lg">
                            <Building2 className="w-6 h-6 text-blue-600" />
                        </div>
                        <h2 className="text-xl font-bold text-slate-900">Connected Organizations</h2>
                    </div>

                    <div className="space-y-4">
                        {organizations.length > 0 ? (
                            organizations.map((org) => (
                                <div key={org.organization_id} className="p-4 border border-slate-200 rounded-xl hover:border-blue-500 transition-colors">
                                    <div className="flex items-center justify-between">
                                        <div>
                                            <h3 className="font-semibold text-slate-900">{org.organization_name}</h3>
                                            <p className="text-sm text-slate-500">{org.organization_type}</p>
                                        </div>
                                        <span className="badge bg-blue-50 text-blue-700 border-blue-200">{org.user_role}</span>
                                    </div>
                                </div>
                            ))
                        ) : (
                            <p className="text-slate-500 text-center py-4">Not connected to any organizations</p>
                        )}
                    </div>
                </div>

                {/* Election History */}
                <div className="card">
                    <div className="flex items-center space-x-3 mb-6">
                        <div className="p-2 bg-purple-100 rounded-lg">
                            <Calendar className="w-6 h-6 text-purple-600" />
                        </div>
                        <h2 className="text-xl font-bold text-slate-900">Election Activity</h2>
                    </div>

                    <div className="space-y-4">
                        {elections.length > 0 ? (
                            elections.map((election) => (
                                <div key={election.election_id} className="p-4 border border-slate-200 rounded-xl hover:border-purple-500 transition-colors">
                                    <div className="flex justify-between items-start mb-2">
                                        <div>
                                            <h3 className="font-semibold text-slate-900">{election.election_name}</h3>
                                            <p className="text-xs text-slate-500">{election.organization_name}</p>
                                        </div>
                                        <span className={`badge ${election.status === 'OPEN' ? 'bg-emerald-100 text-emerald-700' :
                                            election.status === 'CLOSED' ? 'bg-slate-100 text-slate-700' :
                                                'bg-amber-100 text-amber-700'
                                            }`}>
                                            {election.status}
                                        </span>
                                    </div>
                                    <div className="flex items-center text-xs text-slate-500">
                                        <Clock className="w-3 h-3 mr-1" />
                                        <span>
                                            {election.start_datetime ? new Date(election.start_datetime).toLocaleDateString() : 'TBD'}
                                        </span>
                                    </div>
                                </div>
                            ))
                        ) : (
                            <p className="text-slate-500 text-center py-4">No election history available</p>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
