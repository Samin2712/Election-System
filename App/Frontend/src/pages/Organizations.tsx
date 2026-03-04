import { useState, useEffect } from 'react';
import { Building2, Plus, Users, X, Crown, Shield, User as UserIcon, Search, Send, CheckCircle, Upload, Clock, XCircle, FileText, ImageIcon } from 'lucide-react';
import toast from 'react-hot-toast';
import { organizationsApi, registrationApi, adminApi } from '@/lib/api';
import { useAuthStore } from '@/store/authStore';
import type { Organization, OrgMember, OrgRequest, OrgRequestFormData } from '@/types';
import InvitationManager from '@/components/InvitationManager';

export default function Organizations() {
    const { setCurrentOrganization, userOrganizations } = useAuthStore();
    const [organizations, setOrganizations] = useState<Organization[]>([]);
    const [loading, setLoading] = useState(true);
    const [showCreateModal, setShowCreateModal] = useState(false);
    const [showRequestModal, setShowRequestModal] = useState(false);
    const [showInviteManager, setShowInviteManager] = useState(false);
    const [selectedOrg, setSelectedOrg] = useState<Organization | null>(null);
    const [members, setMembers] = useState<OrgMember[]>([]);
    const [searchTerm, setSearchTerm] = useState('');
    const [requestMessage, setRequestMessage] = useState('');
    const [myRequests, setMyRequests] = useState<OrgRequest[]>([]);
    const [isSuperAdmin, setIsSuperAdmin] = useState(false);
    const [submitting, setSubmitting] = useState(false);
    const [proofPreview, setProofPreview] = useState<string | null>(null);

    // Form state for org request
    const [formData, setFormData] = useState<OrgRequestFormData>({
        organization_name: '',
        organization_type: 'UNIVERSITY',
        organization_code: '',
        purpose: '',
        expected_members: undefined,
        proof_document: null,
    });

    useEffect(() => {
        loadOrganizations();
        loadMyRequests();
        checkAdmin();
    }, []);

    const checkAdmin = async () => {
        const isAdmin = await adminApi.checkSuperAdmin();
        setIsSuperAdmin(isAdmin);
    };

    const loadMyRequests = async () => {
        try {
            const data = await adminApi.getMyRequests();
            setMyRequests(data);
        } catch (error: any) {
            console.error('Failed to load requests:', error);
        }
    };

    const loadOrganizations = async () => {
        setLoading(true);
        try {
            // Load ALL organizations for browsing
            const data = await organizationsApi.getAll();
            setOrganizations(data);
        } catch (error: any) {
            toast.error('Failed to load organizations');
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const loadMembers = async (orgId: number) => {
        try {
            const data = await organizationsApi.getMembers(orgId);
            setMembers(data);
        } catch (error: any) {
            toast.error('Failed to load members');
            console.error(error);
        }
    };

    const handleCreate = async (e: React.FormEvent) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            if (isSuperAdmin) {
                // Super admin can create directly
                await adminApi.createOrganization({
                    organization_name: formData.organization_name,
                    organization_type: formData.organization_type,
                    organization_code: formData.organization_code,
                });
                toast.success('Organization created successfully!');
            } else {
                // Regular user submits a request
                await adminApi.submitOrgRequest(formData);
                toast.success('Organization request submitted! Waiting for admin approval.');
                loadMyRequests();
            }
            setShowCreateModal(false);
            setFormData({ organization_name: '', organization_type: 'UNIVERSITY', organization_code: '', purpose: '', expected_members: undefined, proof_document: null });
            setProofPreview(null);
            loadOrganizations();
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to submit request');
        } finally {
            setSubmitting(false);
        }
    };

    const handleProofChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0] || null;
        setFormData({ ...formData, proof_document: file });
        if (file) {
            const reader = new FileReader();
            reader.onloadend = () => setProofPreview(reader.result as string);
            reader.readAsDataURL(file);
        } else {
            setProofPreview(null);
        }
    };

    const getStatusBadge = (status: string) => {
        switch (status) {
            case 'PENDING':
                return (
                    <span className="inline-flex items-center space-x-1 px-3 py-1 rounded-full text-sm font-medium bg-yellow-100 text-yellow-800">
                        <Clock className="w-3.5 h-3.5" />
                        <span>Pending</span>
                    </span>
                );
            case 'APPROVED':
                return (
                    <span className="inline-flex items-center space-x-1 px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                        <CheckCircle className="w-3.5 h-3.5" />
                        <span>Approved</span>
                    </span>
                );
            case 'REJECTED':
                return (
                    <span className="inline-flex items-center space-x-1 px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800">
                        <XCircle className="w-3.5 h-3.5" />
                        <span>Rejected</span>
                    </span>
                );
            default:
                return null;
        }
    };

    const handleSelectOrg = async (org: Organization) => {
        setSelectedOrg(org);
        setCurrentOrganization(org);
        await loadMembers(org.organization_id);
    };

    const isAlreadyMember = (orgId: number) => {
        return userOrganizations.some(org => org.organization_id === orgId);
    };

    const getUserRoleInOrg = (orgId: number): 'OWNER' | 'ADMIN' | 'MEMBER' | null => {
        const org = userOrganizations.find(o => o.organization_id === orgId);
        return org?.user_role || null;
    };

    const isOwnerOrAdmin = (orgId: number): boolean => {
        const role = getUserRoleInOrg(orgId);
        return role === 'OWNER' || role === 'ADMIN';
    };

    const handleRequestJoin = (org: Organization) => {
        setSelectedOrg(org);
        setShowRequestModal(true);
    };

    const submitJoinRequest = async () => {
        if (!selectedOrg) return;

        try {
            await registrationApi.requestToJoin(selectedOrg.organization_id, requestMessage);
            toast.success('Join request submitted! Wait for organizer approval.');
            setShowRequestModal(false);
            setRequestMessage('');
            setSelectedOrg(null);
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Failed to submit request');
        }
    };

    const getRoleIcon = (role: string) => {
        switch (role) {
            case 'OWNER':
                return <Crown className="w-4 h-4 text-yellow-600" />;
            case 'ADMIN':
                return <Shield className="w-4 h-4 text-blue-600" />;
            case 'MEMBER':
                return <UserIcon className="w-4 h-4 text-slate-600" />;
            default:
                return <UserIcon className="w-4 h-4 text-slate-600" />;
        }
    };

    const getRoleBadgeClass = (role: string) => {
        switch (role) {
            case 'OWNER':
                return 'badge bg-gradient-to-r from-yellow-400 to-orange-500 text-white border-0';
            case 'ADMIN':
                return 'badge bg-gradient-to-r from-blue-500 to-indigo-600 text-white border-0';
            case 'MEMBER':
                return 'badge-primary';
            default:
                return 'badge-primary';
        }
    };

    const filteredOrganizations = organizations.filter(org =>
        org.organization_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        org.organization_code.toLowerCase().includes(searchTerm.toLowerCase())
    );

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <div className="spinner w-16 h-16 mx-auto mb-4"></div>
                    <p className="text-slate-600 font-medium">Loading organizations...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                <div>
                    <h1 className="text-4xl font-black gradient-text mb-2">Organizations</h1>
                    <p className="text-slate-600">{isSuperAdmin ? 'Browse all organizations on the platform' : 'Manage your organizations and members'}</p>
                </div>
                {!isSuperAdmin && (
                    <button
                        onClick={() => setShowCreateModal(true)}
                        className="btn-primary flex items-center"
                    >
                        <Plus className="w-5 h-5 mr-2" />
                        Request Organization
                    </button>
                )}
            </div>

            {/* Search Bar */}
            <div className="card">
                <div className="relative">
                    <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-slate-400" />
                    <input
                        type="text"
                        placeholder="Search organizations by name or code..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="input pl-12"
                    />
                </div>
            </div>

            {/* My Organization Requests (hidden for super admin) */}
            {!isSuperAdmin && myRequests.length > 0 && (
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-slate-900 flex items-center space-x-2">
                        <FileText className="w-5 h-5 text-blue-600" />
                        <span>My Organization Requests</span>
                    </h2>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {myRequests.map((req) => (
                            <div key={req.request_id} className="card border-l-4 border-l-blue-500">
                                <div className="flex items-start justify-between mb-3">
                                    <div>
                                        <h3 className="font-bold text-slate-900">{req.organization_name}</h3>
                                        <p className="text-sm text-slate-500">{req.organization_type} &middot; {req.organization_code}</p>
                                    </div>
                                    {getStatusBadge(req.status)}
                                </div>
                                {req.purpose && (
                                    <p className="text-sm text-slate-600 mb-2 line-clamp-2">{req.purpose}</p>
                                )}
                                {req.proof_document_url && (
                                    <div className="mb-2">
                                        <img
                                            src={`/uploads/${req.proof_document_url}`}
                                            alt="Proof document"
                                            className="w-full h-24 object-cover rounded-lg border border-slate-200"
                                        />
                                    </div>
                                )}
                                {req.admin_notes && (
                                    <div className={`text-sm p-2 rounded-lg mt-2 ${req.status === 'REJECTED' ? 'bg-red-50 text-red-700' : 'bg-green-50 text-green-700'}`}>
                                        <span className="font-medium">Admin Note:</span> {req.admin_notes}
                                    </div>
                                )}
                                <p className="text-xs text-slate-400 mt-2">
                                    Submitted {new Date(req.created_at).toLocaleDateString()}
                                </p>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* Organizations Grid */}
            {filteredOrganizations.length > 0 ? (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    {filteredOrganizations.map((org) => (
                        <div
                            key={org.organization_id}
                            className={`card hover-lift cursor-pointer ${selectedOrg?.organization_id === org.organization_id
                                ? 'ring-4 ring-blue-500 ring-opacity-50'
                                : ''
                                }`}
                            onClick={() => handleSelectOrg(org)}
                        >
                            <div className="flex items-start justify-between mb-4">
                                <div className="flex items-start space-x-4">
                                    <div className="p-4 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-2xl">
                                        <Building2 className="w-8 h-8 text-white" />
                                    </div>
                                    <div>
                                        <h3 className="text-xl font-bold text-slate-900 mb-1">
                                            {org.organization_name}
                                        </h3>
                                        <p className="text-sm text-slate-600 mb-2">{org.organization_type}</p>
                                        <p className="text-xs font-mono text-slate-500 bg-slate-100 px-3 py-1 rounded-lg inline-block">
                                            {org.organization_code}
                                        </p>
                                    </div>
                                </div>
                            </div>

                            {/* Request to Join Button for non-members (hidden for super admin) */}
                            {!isSuperAdmin && !isAlreadyMember(org.organization_id) && (
                                <div className="mt-4">
                                    <button
                                        onClick={(e) => {
                                            e.stopPropagation();
                                            handleRequestJoin(org);
                                        }}
                                        className="btn-primary w-full flex items-center justify-center space-x-2"
                                    >
                                        <Send className="w-4 h-4" />
                                        <span>Request to Join</span>
                                    </button>
                                </div>
                            )}

                            {/* Member Badge for existing members (hidden for super admin) */}
                            {!isSuperAdmin && isAlreadyMember(org.organization_id) && (
                                <div className="mt-4">
                                    <div className="flex items-center justify-center space-x-2 bg-green-100 text-green-700 px-4 py-2 rounded-lg">
                                        <CheckCircle className="w-4 h-4" />
                                        <span className="font-medium">Already a Member</span>
                                    </div>
                                </div>
                            )}

                            {selectedOrg?.organization_id === org.organization_id && members.length > 0 && (
                                <div className="mt-4 pt-4 border-t border-slate-200">
                                    <div className="flex items-center justify-between mb-3">
                                        <h4 className="font-semibold text-slate-900 flex items-center">
                                            <Users className="w-4 h-4 mr-2" />
                                            Members ({members.length})
                                        </h4>
                                        {isOwnerOrAdmin(org.organization_id) && (
                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    setShowInviteManager(true);
                                                }}
                                                className="text-sm text-blue-600 hover:text-blue-700 font-medium flex items-center space-x-1"
                                            >
                                                <Upload className="w-4 h-4" />
                                                <span>Bulk Invite</span>
                                            </button>
                                        )}
                                    </div>
                                    <div className="space-y-2 max-h-48 overflow-y-auto">
                                        {members.map((member) => (
                                            <div
                                                key={member.user_id}
                                                className="flex items-center justify-between p-3 bg-slate-50 rounded-xl"
                                            >
                                                <div className="flex items-center space-x-3">
                                                    <div className="w-10 h-10 rounded-full bg-gradient-to-r from-blue-600 to-indigo-600 flex items-center justify-center text-white font-bold">
                                                        {member.username?.charAt(0).toUpperCase()}
                                                    </div>
                                                    <div>
                                                        <p className="font-semibold text-slate-900">{member.username}</p>
                                                        <p className="text-xs text-slate-500">{member.email}</p>
                                                    </div>
                                                </div>
                                                <span className={`${getRoleBadgeClass(member.role_name)} flex items-center space-x-1`}>
                                                    {getRoleIcon(member.role_name)}
                                                    <span>{member.role_name}</span>
                                                </span>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>
                    ))}
                </div>
            ) : (
                <div className="card empty-state">
                    <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full mb-6">
                        <Building2 className="w-10 h-10 text-blue-600" />
                    </div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-3">
                        {searchTerm ? 'No organizations found' : 'No Organizations Yet'}
                    </h3>
                    <p className="text-slate-600 mb-8">
                        {searchTerm
                            ? 'Try adjusting your search terms'
                            : isSuperAdmin
                                ? 'No organizations have been created yet'
                                : 'Request your first organization to get started'}
                    </p>
                    {!searchTerm && !isSuperAdmin && (
                        <button onClick={() => setShowCreateModal(true)} className="btn-primary inline-flex items-center">
                            <Plus className="w-5 h-5 mr-2" />
                            Request Organization
                        </button>
                    )}
                </div>
            )}

            {/* Create / Request Organization Modal */}
            {showCreateModal && (
                <div className="modal-overlay" onClick={() => setShowCreateModal(false)}>
                    <div className="modal-content p-8 max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">
                                {isSuperAdmin ? 'Create Organization' : 'Request Organization'}
                            </h2>
                            <button
                                onClick={() => setShowCreateModal(false)}
                                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
                            >
                                <X className="w-6 h-6" />
                            </button>
                        </div>

                        {!isSuperAdmin && (
                            <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-6">
                                <p className="text-sm text-blue-800">
                                    <span className="font-semibold">Note:</span> Organization requests are reviewed by a super admin.
                                    Please upload a proof document (e.g., transcript, visiting card, ID card) to speed up approval.
                                </p>
                            </div>
                        )}

                        <form onSubmit={handleCreate} className="space-y-5">
                            <div className="form-group">
                                <label className="label">Organization Name *</label>
                                <input
                                    type="text"
                                    required
                                    value={formData.organization_name}
                                    onChange={(e) => setFormData({ ...formData, organization_name: e.target.value })}
                                    className="input"
                                    placeholder="e.g., State University"
                                />
                            </div>

                            <div className="form-group">
                                <label className="label">Organization Type *</label>
                                <select
                                    required
                                    value={formData.organization_type}
                                    onChange={(e) => setFormData({ ...formData, organization_type: e.target.value })}
                                    className="input"
                                >
                                    <option value="UNIVERSITY">University</option>
                                    <option value="SCHOOL">School</option>
                                    <option value="COLLEGE">College</option>
                                    <option value="CLUB">Club</option>
                                    <option value="COMPANY">Company</option>
                                    <option value="NGO">NGO</option>
                                    <option value="GOVERNMENT">Government</option>
                                    <option value="OTHER">Other</option>
                                </select>
                            </div>

                            <div className="form-group">
                                <label className="label">Organization Code *</label>
                                <input
                                    type="text"
                                    required
                                    value={formData.organization_code}
                                    onChange={(e) => setFormData({ ...formData, organization_code: e.target.value.toUpperCase() })}
                                    className="input font-mono"
                                    placeholder="e.g., SU2024"
                                    maxLength={20}
                                />
                                <p className="text-xs text-slate-500 mt-1">Unique identifier for your organization</p>
                            </div>

                            {/* Additional fields for non-admin users */}
                            {!isSuperAdmin && (
                                <>
                                    <div className="form-group">
                                        <label className="label">Purpose / Reason *</label>
                                        <textarea
                                            required
                                            value={formData.purpose || ''}
                                            onChange={(e) => setFormData({ ...formData, purpose: e.target.value })}
                                            className="input min-h-[80px]"
                                            rows={3}
                                            placeholder="Why do you need this organization? e.g., Student body elections for Fall 2024 semester"
                                        />
                                    </div>

                                    <div className="form-group">
                                        <label className="label">Expected Members</label>
                                        <input
                                            type="number"
                                            min={1}
                                            value={formData.expected_members || ''}
                                            onChange={(e) => setFormData({ ...formData, expected_members: e.target.value ? Number(e.target.value) : undefined })}
                                            className="input"
                                            placeholder="e.g., 500"
                                        />
                                    </div>

                                    <div className="form-group">
                                        <label className="label">Proof Document (Image) *</label>
                                        <p className="text-xs text-slate-500 mb-2">
                                            Upload an image of a transcript, visiting card, institution ID, or other proof of affiliation
                                        </p>
                                        <div className="relative">
                                            <input
                                                type="file"
                                                required
                                                accept="image/*"
                                                onChange={handleProofChange}
                                                className="hidden"
                                                id="proof-upload"
                                            />
                                            <label
                                                htmlFor="proof-upload"
                                                className="flex items-center justify-center w-full p-6 border-2 border-dashed border-slate-300 rounded-xl cursor-pointer hover:border-blue-400 hover:bg-blue-50 transition-colors"
                                            >
                                                {proofPreview ? (
                                                    <img
                                                        src={proofPreview}
                                                        alt="Proof preview"
                                                        className="max-h-48 rounded-lg object-contain"
                                                    />
                                                ) : (
                                                    <div className="text-center">
                                                        <ImageIcon className="w-10 h-10 text-slate-400 mx-auto mb-2" />
                                                        <p className="text-sm text-slate-600 font-medium">Click to upload proof document</p>
                                                        <p className="text-xs text-slate-400 mt-1">JPG, PNG, GIF up to 10MB</p>
                                                    </div>
                                                )}
                                            </label>
                                        </div>
                                        {formData.proof_document && (
                                            <p className="text-xs text-green-600 mt-1 flex items-center space-x-1">
                                                <CheckCircle className="w-3 h-3" />
                                                <span>{formData.proof_document.name}</span>
                                            </p>
                                        )}
                                    </div>
                                </>
                            )}

                            <div className="flex space-x-3 pt-4">
                                <button type="submit" className="btn-primary flex-1" disabled={submitting}>
                                    {submitting
                                        ? 'Submitting...'
                                        : isSuperAdmin
                                            ? 'Create Organization'
                                            : 'Submit Request'}
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

            {/* Request to Join Modal */}
            {showRequestModal && (
                <div className="modal-overlay" onClick={() => setShowRequestModal(false)}>
                    <div className="modal-content max-w-md p-8" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">
                                Request to Join {selectedOrg?.organization_name}
                            </h2>
                            <button
                                onClick={() => setShowRequestModal(false)}
                                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
                            >
                                <X className="w-6 h-6" />
                            </button>
                        </div>

                        <div className="space-y-4">
                            <div className="form-group">
                                <label className="label">Message (Optional)</label>
                                <textarea
                                    value={requestMessage}
                                    onChange={(e) => setRequestMessage(e.target.value)}
                                    placeholder="Why do you want to join this organization?"
                                    className="input min-h-[100px]"
                                    rows={4}
                                />
                                <p className="text-xs text-slate-500 mt-1">
                                    This message will be sent to the organization administrators
                                </p>
                            </div>

                            <div className="flex space-x-3 pt-4">
                                <button
                                    onClick={submitJoinRequest}
                                    className="btn-primary flex-1 flex items-center justify-center space-x-2"
                                >
                                    <Send className="w-4 h-4" />
                                    <span>Submit Request</span>
                                </button>
                                <button
                                    onClick={() => setShowRequestModal(false)}
                                    className="btn-secondary"
                                >
                                    Cancel
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Invitation Manager Modal */}
            {showInviteManager && selectedOrg && (
                <div className="modal-overlay" onClick={() => setShowInviteManager(false)}>
                    <div className="modal-content max-w-4xl max-h-[90vh] overflow-y-auto p-8" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-between mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">
                                Manage Invitations - {selectedOrg.organization_name}
                            </h2>
                            <button
                                onClick={() => setShowInviteManager(false)}
                                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
                            >
                                <X className="w-6 h-6" />
                            </button>
                        </div>
                        <InvitationManager 
                            organizationId={selectedOrg.organization_id}
                            organizationName={selectedOrg.organization_name}
                            isOwnerOrAdmin={isOwnerOrAdmin(selectedOrg.organization_id)}
                        />
                    </div>
                </div>
            )}
        </div>
    );
}
