import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/store/authStore';
import { adminApi } from '@/lib/api';
import OrganizerDashboard from './OrganizerDashboard';
import VoterDashboard from './VoterDashboard';

export default function Dashboard() {
    const { currentOrganizationRole } = useAuthStore();
    const navigate = useNavigate();
    const [checked, setChecked] = useState(false);

    useEffect(() => {
        adminApi.checkSuperAdmin().then((isAdmin) => {
            if (isAdmin) {
                navigate('/admin', { replace: true });
            } else {
                setChecked(true);
            }
        });
    }, []);

    if (!checked) return null;

    // Determine which dashboard to show based on role
    const isOrganizer = currentOrganizationRole === 'OWNER' || currentOrganizationRole === 'ADMIN';

    // Show organizer dashboard for OWNER/ADMIN, voter dashboard for MEMBER
    if (isOrganizer) {
        return <OrganizerDashboard />;
    }

    return <VoterDashboard />;
}
