// User & Auth Types
export interface User {
    user_id: number;
    username: string;
    email: string;
    role_id: number;
    is_active: boolean;
}

export interface AuthResponse {
    ok: boolean;
    user_id?: number;
    accessToken?: string;
    refreshToken?: string;
    error?: string;
}

export interface LoginCredentials {
    email: string;
    password: string;
}

export interface RegisterData {
    username: string;
    email: string;
    password: string;
}

// Organization Types
export type OrganizationStatus = 'PENDING' | 'ACTIVE' | 'SUSPENDED' | 'ARCHIVED';

export interface Organization {
    organization_id: number;
    organization_name: string;
    organization_type: string;
    organization_code: string;
    status?: OrganizationStatus;
    created_at?: string;
}

export interface UserOrganization {
    organization_id: number;
    organization_name: string;
    organization_type: string;
    organization_code: string;
    organization_status: OrganizationStatus;
    user_role: 'OWNER' | 'ADMIN' | 'MEMBER';
    is_member_active: boolean;
    joined_at: string;
}

export interface OrgMember {
    user_id: number;
    username: string;
    email: string;
    role_name: 'OWNER' | 'ADMIN' | 'MEMBER';
    is_active: boolean;
    joined_at: string;
}

// Election Types
export type ElectionStatus = 'DRAFT' | 'SCHEDULED' | 'OPEN' | 'CLOSED' | 'ARCHIVED';

export interface Election {
    election_id: number;
    organization_id: number;
    organization_name?: string;
    election_name: string;
    description?: string;
    start_datetime?: string;
    end_datetime?: string;
    status: ElectionStatus;
    created_at: string;
    created_by: number;
}

export interface ElectionWithDetails extends Election {
    races: Race[];
}

// Race Types
export interface Race {
    race_id: number;
    race_name: string;
    description?: string;
    max_votes_per_voter: number;
    max_winners: number;
    candidate_count?: number;
    candidates?: Candidate[];
}

export interface RaceFormData {
    election_id: number;
    race_name: string;
    description?: string;
    max_votes_per_voter: number;
}

// Candidate Types
export interface Candidate {
    candidate_id: number;
    full_name: string;
    affiliation_name?: string;
    bio?: string;
    manifesto?: string;
    is_approved: boolean;
    ballot_order?: number;
    display_name?: string;
}

export interface CandidateFormData {
    full_name: string;
    affiliation_name?: string;
    bio?: string;
    manifesto?: string;
    ballot_order?: number;
}

// Voter Types
export type VoterStatus = 'PENDING' | 'APPROVED' | 'BLOCKED';

export interface Voter {
    voter_id: number;
    user_id: number;
    username?: string;
    email?: string;
    member_id?: string;
    voter_type?: string;
    status: VoterStatus;
    is_approved: boolean;
    approved_by?: number;
    approved_at?: string;
    registered_at: string;
}

export interface VoterStatusResponse {
    ok: boolean;
    registered: boolean;
    voter?: Voter;
    message?: string;
}

// Vote Types
export interface VoteData {
    election_id: number;
    race_id: number;
    candidate_id: number;
    voter_user_id?: number;
    voter_id?: number;
}

export interface RaceResult {
    candidate_id: number;
    display_name: string;
    vote_count: number;
}

export interface ResultsResponse {
    ok: boolean;
    election_id: number;
    race_id: number;
    race_name: string;
    election_status: ElectionStatus;
    results: RaceResult[];
}

// API Response Types
export interface ApiResponse<T = any> {
    ok: boolean;
    data?: T;
    error?: string;
    message?: string;
}

export interface PaginatedResponse<T> {
    ok: boolean;
    data: T[];
    total: number;
    page: number;
    limit: number;
}
