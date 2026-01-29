import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { User, Organization, UserOrganization } from '@/types';
import { authApi } from '@/lib/api';

interface AuthState {
    user: User | null;
    accessToken: string | null;
    refreshToken: string | null;
    isAuthenticated: boolean;
    currentOrganization: Organization | null;
    currentOrganizationRole: 'OWNER' | 'ADMIN' | 'MEMBER' | null;
    userOrganizations: UserOrganization[];
    setUser: (user: User | null) => void;
    setTokens: (accessToken: string, refreshToken: string) => void;
    setCurrentOrganization: (org: Organization | null) => void;
    setCurrentOrganizationRole: (role: 'OWNER' | 'ADMIN' | 'MEMBER' | null) => void;
    setUserOrganizations: (orgs: UserOrganization[]) => void;
    switchOrganization: (orgId: number) => void;
    logout: () => void;
}

export const useAuthStore = create<AuthState>()(
    persist(
        (set, get) => ({
            user: null,
            accessToken: null,
            refreshToken: null,
            isAuthenticated: false,
            currentOrganization: null,
            currentOrganizationRole: null,
            userOrganizations: [],

            setUser: (user) => set({ user, isAuthenticated: !!user }),

            setTokens: (accessToken, refreshToken) => {
                localStorage.setItem('accessToken', accessToken);
                localStorage.setItem('refreshToken', refreshToken);
                set({ accessToken, refreshToken, isAuthenticated: true });
            },

            setCurrentOrganization: (org) => set({ currentOrganization: org }),

            setCurrentOrganizationRole: (role) => set({ currentOrganizationRole: role }),

            setUserOrganizations: (orgs) => {
                console.log('📋 setUserOrganizations called with:', orgs.map(o => ({ id: o.organization_id, name: o.organization_name, role: o.user_role })));

                set({ userOrganizations: orgs });

                // Auto-select first organization ONLY if:
                // 1. No organization is currently selected AND
                // 2. Organizations list was just populated
                const current = get().currentOrganization;
                console.log('🔍 Current organization before update:', current ? { id: current.organization_id, name: current.organization_name } : 'NONE');
                console.log('🔍 Current role before update:', get().currentOrganizationRole);

                if (!current && orgs.length > 0) {
                    console.log('🆕 No org selected, auto-selecting first one');
                    const firstOrg = orgs[0];
                    set({
                        currentOrganization: {
                            organization_id: firstOrg.organization_id,
                            organization_name: firstOrg.organization_name,
                            organization_type: firstOrg.organization_type,
                            organization_code: firstOrg.organization_code,
                            status: firstOrg.organization_status,
                        },
                        currentOrganizationRole: firstOrg.user_role,
                    });
                    console.log('✅ Auto-selected:', { name: firstOrg.organization_name, role: firstOrg.user_role });
                } else if (current && orgs.length > 0) {
                    // If an org is already selected, update its data in case it changed
                    const updatedOrg = orgs.find(o => o.organization_id === current.organization_id);
                    console.log('🔄 Updating current org data:', updatedOrg ? { name: updatedOrg.organization_name, role: updatedOrg.user_role } : 'NOT FOUND IN NEW LIST');

                    if (updatedOrg) {
                        set({
                            currentOrganization: {
                                organization_id: updatedOrg.organization_id,
                                organization_name: updatedOrg.organization_name,
                                organization_type: updatedOrg.organization_type,
                                organization_code: updatedOrg.organization_code,
                                status: updatedOrg.organization_status,
                            },
                            currentOrganizationRole: updatedOrg.user_role,
                        });
                        console.log('✅ Updated current org role to:', updatedOrg.user_role);
                    }
                }
            },

            switchOrganization: (orgId) => {
                const orgs = get().userOrganizations;

                console.log('🔍 DEBUG switchOrganization:', {
                    searchingForOrgId: orgId,
                    orgIdType: typeof orgId,
                    totalOrgsAvailable: orgs.length,
                    rawOrgs: orgs,
                });

                const targetOrg = orgs.find(o => {
                    console.log(`Comparing: ${o.organization_id} (${typeof o.organization_id}) === ${orgId} (${typeof orgId})`);
                    return String(o.organization_id) === String(orgId);
                });

                console.log('🔄 switchOrganization called:', {
                    orgId,
                    availableOrgs: orgs.map(o => ({ id: o.organization_id, name: o.organization_name, role: o.user_role })),
                    targetOrg: targetOrg ? { id: targetOrg.organization_id, name: targetOrg.organization_name, role: targetOrg.user_role } : 'NOT FOUND'
                });

                if (targetOrg) {
                    console.log('✅ Setting organization:', {
                        orgName: targetOrg.organization_name,
                        role: targetOrg.user_role
                    });
                    set({
                        currentOrganization: {
                            organization_id: targetOrg.organization_id,
                            organization_name: targetOrg.organization_name,
                            organization_type: targetOrg.organization_type,
                            organization_code: targetOrg.organization_code,
                            status: targetOrg.organization_status,
                        },
                        currentOrganizationRole: targetOrg.user_role,
                    });
                } else {
                    console.error('❌ Organization not found in userOrganizations list!');
                    console.error('Available org IDs:', orgs.map(o => o.organization_id));
                    console.error('Tried to find org ID:', orgId);
                }
            },

            logout: () => {
                authApi.logout();
                set({
                    user: null,
                    accessToken: null,
                    refreshToken: null,
                    isAuthenticated: false,
                    currentOrganization: null,
                    currentOrganizationRole: null,
                    userOrganizations: [],
                });
            },
        }),
        {
            name: 'auth-storage',
            partialize: (state) => ({
                user: state.user,
                accessToken: state.accessToken,
                refreshToken: state.refreshToken,
                isAuthenticated: state.isAuthenticated,
                currentOrganization: state.currentOrganization,
                currentOrganizationRole: state.currentOrganizationRole,
                userOrganizations: state.userOrganizations,
            }),
        }
    )
);
