import { Outlet, Link, useNavigate, useLocation } from 'react-router-dom';
import { LogOut, Home, Building2, Vote, BarChart3, Users, Sparkles } from 'lucide-react';
import { useAuthStore } from '@/store/authStore';
import OrganizationSelector from './OrganizationSelector';

export default function Layout() {
    const navigate = useNavigate();
    const location = useLocation();
    const { user, logout, currentOrganizationRole } = useAuthStore();

    const handleLogout = () => {
        logout();
        navigate('/login');
    };

    const isActive = (path: string) => {
        return location.pathname === path;
    };

    const navLinkClass = (path: string) => {
        const base = "flex items-center space-x-2 px-4 py-2.5 rounded-xl font-medium transition-all duration-300";
        if (isActive(path)) {
            return `${base} bg-gradient-to-r from-blue-600 to-indigo-600 text-white shadow-lg shadow-blue-500/30`;
        }
        return `${base} text-slate-600 hover:text-blue-600 hover:bg-white/80 hover:shadow-md`;
    };

    // Determine if user should see voter features
    // OWNER and ADMIN manage elections, they don't vote
    // Only MEMBER role can vote
    const canVote = currentOrganizationRole === 'MEMBER';

    return (
        <div className="min-h-screen">
            {/* Premium Header with Glassmorphism */}
            <header className="glass-panel sticky top-0 z-50 border-b border-white/20">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="flex justify-between items-center h-20">
                        {/* Logo and Brand */}
                        <div className="flex items-center space-x-8">
                            <Link to="/" className="flex items-center space-x-3 group">
                                <div className="relative">
                                    <div className="absolute inset-0 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-xl blur-lg opacity-50 group-hover:opacity-75 transition-opacity"></div>
                                    <div className="relative p-2 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-xl">
                                        <Vote className="w-7 h-7 text-white" />
                                    </div>
                                </div>
                                <div>
                                    <span className="text-2xl font-bold gradient-text">Election System</span>
                                    <div className="flex items-center space-x-1 text-xs text-slate-500">
                                        <Sparkles className="w-3 h-3" />
                                        <span>Powered by Democracy</span>
                                    </div>
                                </div>
                            </Link>

                            {/* Navigation */}
                            <nav className="hidden lg:flex items-center space-x-2">
                                <Link to="/" className={navLinkClass('/')}>
                                    <Home className="w-4 h-4" />
                                    <span>Dashboard</span>
                                </Link>
                                <Link to="/organizations" className={navLinkClass('/organizations')}>
                                    <Building2 className="w-4 h-4" />
                                    <span>Organizations</span>
                                </Link>
                                <Link to="/elections" className={navLinkClass('/elections')}>
                                    <BarChart3 className="w-4 h-4" />
                                    <span>Elections</span>
                                </Link>
                                {/* Only show Vote tab for MEMBER role */}
                                {canVote && (
                                    <Link to="/vote" className={navLinkClass('/vote')}>
                                        <Users className="w-4 h-4" />
                                        <span>Vote</span>
                                    </Link>
                                )}
                            </nav>
                        </div>

                        {/* Right Side Actions */}
                        <div className="flex items-center space-x-4">
                            {/* Organization Selector */}
                            <OrganizationSelector />

                            {/* User Profile */}
                            <div className="flex items-center space-x-3 border-l border-slate-200 pl-4">
                                <Link to="/profile" className="flex items-center space-x-3 group cursor-pointer">
                                    <div className="text-right hidden sm:block">
                                        <p className="text-sm font-semibold text-slate-900 group-hover:text-blue-600 transition-colors">{user?.username}</p>
                                        <p className="text-xs text-slate-500">{user?.email}</p>
                                    </div>
                                    <div className="relative">
                                        <div className="w-10 h-10 rounded-full bg-gradient-to-r from-blue-600 to-indigo-600 flex items-center justify-center text-white font-bold shadow-lg group-hover:scale-105 transition-transform">
                                            {user?.username?.charAt(0).toUpperCase()}
                                        </div>
                                        <div className="absolute bottom-0 right-0 w-3 h-3 bg-emerald-500 border-2 border-white rounded-full"></div>
                                    </div>
                                </Link>
                                <button
                                    onClick={handleLogout}
                                    className="p-2.5 text-slate-500 hover:text-red-600 hover:bg-red-50 rounded-xl transition-all duration-300"
                                    title="Logout"
                                >
                                    <LogOut className="w-5 h-5" />
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </header>

            {/* Main Content with Padding */}
            <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                <Outlet />
            </main>

            {/* Premium Footer */}
            <footer className="glass-panel border-t border-white/20 mt-16">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                    <div className="flex flex-col md:flex-row justify-between items-center space-y-4 md:space-y-0">
                        <p className="text-sm text-slate-600">
                            © 2024 <span className="font-semibold gradient-text">Election Management System</span>. All rights reserved.
                        </p>
                        <div className="flex items-center space-x-6 text-sm text-slate-600">
                            <a href="#" className="hover:text-blue-600 transition-colors">Privacy Policy</a>
                            <a href="#" className="hover:text-blue-600 transition-colors">Terms of Service</a>
                            <a href="#" className="hover:text-blue-600 transition-colors">Support</a>
                        </div>
                    </div>
                </div>
            </footer>
        </div>
    );
}
