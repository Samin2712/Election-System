import { useAuthStore } from '@/store/authStore';
import OrganizerDashboard from './OrganizerDashboard';
import VoterDashboard from './VoterDashboard';

export default function Dashboard() {
    const { currentOrganizationRole } = useAuthStore();

    // Determine which dashboard to show based on role
    const isOrganizer = currentOrganizationRole === 'OWNER' || currentOrganizationRole === 'ADMIN';

    // Show organizer dashboard for OWNER/ADMIN, voter dashboard for MEMBER
    if (isOrganizer) {
        return <OrganizerDashboard />;
    }

    return <VoterDashboard />;
}
