import axios, { AxiosError } from 'axios';
import type {
    AuthResponse,
    LoginCredentials,
    RegisterData,
    Organization,
    UserOrganization,
    Election,
    ElectionWithDetails,
    Race,
    RaceFormData,
    Candidate,
    CandidateFormData,
    VoterStatusResponse,
    VoteData,
    ResultsResponse,
    Voter,
    OrgMember,
} from '@/types';

const API_BASE_URL = '/api';

// Create axios instance
const api = axios.create({
    baseURL: API_BASE_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Request interceptor to add auth token AND organization context
api.interceptors.request.use(
    (config) => {
        const token = localStorage.getItem('accessToken');
        if (token) {
            config.headers.Authorization = `Bearer ${token}`;
        }

        // Add current organization ID to all requests
        const authStorage = localStorage.getItem('auth-storage');
        if (authStorage) {
            try {
                const authState = JSON.parse(authStorage);
                const currentOrgId = authState.state?.currentOrganization?.organization_id;
                if (currentOrgId) {
                    config.headers['X-Organization-Id'] = currentOrgId.toString();
                    console.log('🌐 API Request with org:', currentOrgId, config.url);
                }
            } catch (e) {
                console.error('Failed to parse auth storage:', e);
            }
        }

        return config;
    },
    (error) => Promise.reject(error)
);

// Response interceptor for error handling
api.interceptors.response.use(
    (response) => response,
    async (error: AxiosError) => {
        if (error.response?.status === 401) {
            // Token expired, logout user
            localStorage.removeItem('accessToken');
            localStorage.removeItem('refreshToken');
            window.location.href = '/login';
        }
        return Promise.reject(error);
    }
);

// Auth API
export const authApi = {
    register: async (data: RegisterData): Promise<AuthResponse> => {
        const response = await api.post('/auth/register', data);
        return response.data;
    },

    login: async (credentials: LoginCredentials): Promise<AuthResponse> => {
        const response = await api.post('/auth/login', credentials);
        return response.data;
    },

    logout: () => {
        localStorage.removeItem('accessToken');
        localStorage.removeItem('refreshToken');
    },
};

// Organizations API
export const organizationsApi = {
    create: async (data: { organization_name: string; organization_type: string; organization_code: string }): Promise<Organization> => {
        const response = await api.post('/orgs', data);
        return response.data;
    },

    list: async (): Promise<Organization[]> => {
        const response = await api.get('/orgs');
        return response.data.organizations || [];
    },

    getById: async (id: number): Promise<Organization> => {
        const response = await api.get(`/orgs/${id}`);
        return response.data.organization;
    },

    getMembers: async (id: number): Promise<OrgMember[]> => {
        const response = await api.get(`/orgs/${id}/members`);
        return response.data.members || [];
    },

    addMember: async (orgId: number, userId: number, roleName: string): Promise<void> => {
        await api.post(`/orgs/${orgId}/members`, { user_id: userId, role_name: roleName });
    },

    removeMember: async (orgId: number, userId: number): Promise<void> => {
        await api.delete(`/orgs/${orgId}/members/${userId}`);
    },

    // Get user's organizations with roles
    getUserOrganizations: async (): Promise<UserOrganization[]> => {
        const response = await api.get('/orgs/my/organizations');
        return response.data.organizations || [];
    },

    // Get user's role in specific organization
    // Get user's role in specific organization
    getUserRole: async (orgId: number): Promise<{ role: string; is_active: boolean }> => {
        const response = await api.get(`/orgs/${orgId}/my-role`);
        return response.data;
    },

    // Create invitation (Organizer)
    createInvite: async (orgId: number, email: string) => {
        const response = await api.post(`/orgs/${orgId}/invites`, { email });
        return response.data; // { ok, token, email }
    },

    // Join organization (User)
    join: async (token: string) => {
        const response = await api.post(`/orgs/join`, { token });
        return response.data;
    },

    // Get all organizations (for browsing)
    getAll: async (): Promise<Organization[]> => {
        const response = await api.get('/orgs/all');
        return response.data.organizations || [];
    },
};

// Elections API
export const electionsApi = {
    create: async (data: { organization_id: number; election_name: string; description?: string }): Promise<Election> => {
        const response = await api.post('/elections', data);
        return response.data;
    },

    list: async (organizationId: number): Promise<Election[]> => {
        const response = await api.get(`/elections?organization_id=${organizationId}`);
        return response.data.elections || [];
    },

    getById: async (id: number): Promise<ElectionWithDetails> => {
        const response = await api.get(`/elections/${id}`);
        return response.data.election;
    },

    update: async (id: number, data: { election_name: string; description?: string; start_at?: string; end_at?: string }): Promise<void> => {
        await api.put(`/elections/${id}`, data);
    },

    schedule: async (id: number, start_datetime: string, end_datetime: string): Promise<void> => {
        await api.post(`/elections/${id}/schedule`, { start_datetime, end_datetime });
    },

    open: async (id: number): Promise<void> => {
        await api.post(`/elections/${id}/open`);
    },

    close: async (id: number): Promise<void> => {
        await api.post(`/elections/${id}/close`);
    },

    delete: async (id: number): Promise<void> => {
        await api.delete(`/elections/${id}`);
    },
};

// Races API
export const racesApi = {
    create: async (data: RaceFormData): Promise<Race> => {
        const response = await api.post('/races', data);
        return response.data;
    },

    listByElection: async (electionId: number): Promise<Race[]> => {
        const response = await api.get(`/races/election/${electionId}`);
        return response.data.races || [];
    },

    getById: async (id: number): Promise<Race> => {
        const response = await api.get(`/races/${id}`);
        return response.data.race;
    },

    update: async (id: number, data: Partial<RaceFormData>): Promise<void> => {
        await api.put(`/races/${id}`, data);
    },

    delete: async (id: number): Promise<void> => {
        await api.delete(`/races/${id}`);
    },
};

// Candidates API
export const candidatesApi = {
    add: async (raceId: number, data: CandidateFormData): Promise<Candidate> => {
        const response = await api.post(`/races/${raceId}/candidates`, data);
        return response.data;
    },

    update: async (raceId: number, candidateId: number, data: CandidateFormData): Promise<void> => {
        await api.put(`/races/${raceId}/candidates/${candidateId}`, data);
    },

    remove: async (raceId: number, candidateId: number): Promise<void> => {
        await api.delete(`/races/${raceId}/candidates/${candidateId}`);
    },
};

// Voting API
export const votingApi = {
    register: async (organizationId: number): Promise<void> => {
        await api.post('/voting/register', { organization_id: organizationId });
    },

    approve: async (organizationId: number, userId: number): Promise<void> => {
        await api.post('/voting/approve', { organization_id: organizationId, user_id: userId });
    },

    castVote: async (data: VoteData): Promise<{ vote_id: number }> => {
        const response = await api.post('/voting/cast', data);
        return response.data;
    },

    getStatus: async (organizationId: number): Promise<VoterStatusResponse> => {
        const response = await api.get(`/voting/status?organization_id=${organizationId}`);
        return response.data;
    },

    getPendingVoters: async (organizationId: number): Promise<Voter[]> => {
        const response = await api.get(`/voting/pending?organization_id=${organizationId}`);
        return response.data.pending_voters || [];
    },

    getResults: async (electionId: number, raceId: number): Promise<ResultsResponse> => {
        const response = await api.get(`/voting/results?election_id=${electionId}&race_id=${raceId}`);
        return response.data;
    },

    getElectionResults: async (electionId: number): Promise<any> => {
        const response = await api.get(`/voting/election-results/${electionId}`);
        return response.data;
    },
};

// Registration Requests API
export const registrationApi = {
    // User requests to join organization
    requestToJoin: async (orgId: number, message?: string): Promise<{ request_id: number }> => {
        const response = await api.post(`/orgs/${orgId}/request-join`, { message });
        return response.data;
    },

    // Organizer gets pending join requests
    getJoinRequests: async (orgId: number): Promise<any[]> => {
        const response = await api.get(`/orgs/${orgId}/join-requests`);
        return response.data.requests || [];
    },

    // Organizer approves join request
    approveJoinRequest: async (requestId: number): Promise<{ token: string; user_email: string; user_name: string }> => {
        const response = await api.post(`/orgs/join-requests/${requestId}/approve`);
        return response.data;
    },

    // Organizer rejects join request
    rejectJoinRequest: async (requestId: number): Promise<void> => {
        await api.post(`/orgs/join-requests/${requestId}/reject`);
    },

    // User completes registration with token
    completeRegistration: async (token: string): Promise<{ organization_id: number; organization_name: string }> => {
        const response = await api.post('/orgs/complete-registration', { token });
        return response.data.organization;
    },
};

export default api;
