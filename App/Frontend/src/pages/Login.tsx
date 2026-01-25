import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { Vote, Mail, Lock, Sparkles } from 'lucide-react';
import toast from 'react-hot-toast';
import { authApi } from '@/lib/api';
import { useAuthStore } from '@/store/authStore';

export default function Login() {
    const navigate = useNavigate();
    const { setTokens, setUser } = useAuthStore();
    const [loading, setLoading] = useState(false);
    const [formData, setFormData] = useState({
        email: '',
        password: '',
    });

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);

        try {
            const response = await authApi.login(formData);

            if (response.ok && response.accessToken && response.refreshToken && response.user_id) {
                // Set tokens first
                setTokens(response.accessToken, response.refreshToken);

                // Set user data
                setUser({
                    user_id: response.user_id,
                    username: formData.email.split('@')[0], // Extract username from email
                    email: formData.email,
                    role_id: 4, // Default role ID
                    is_active: true,
                });

                toast.success('Welcome back! 🎉');
                navigate('/');
            } else {
                toast.error(response.error || 'Login failed');
            }
        } catch (error: any) {
            toast.error(error.response?.data?.error || 'Login failed. Please check your credentials.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center px-4 py-12">
            <div className="max-w-md w-full">
                {/* Logo and Header */}
                <div className="text-center mb-8">
                    <div className="relative inline-block mb-6">
                        <div className="absolute inset-0 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-3xl blur-2xl opacity-50"></div>
                        <div className="relative p-4 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-3xl shadow-2xl">
                            <Vote className="w-12 h-12 text-white" />
                        </div>
                    </div>
                    <h1 className="text-5xl font-black gradient-text mb-3">Election System</h1>
                    <p className="text-slate-600 text-lg flex items-center justify-center space-x-2">
                        <Sparkles className="w-5 h-5 text-blue-600" />
                        <span>Sign in to manage your elections</span>
                    </p>
                </div>

                {/* Login Form */}
                <div className="glass-panel rounded-3xl p-8 shadow-2xl">
                    <form onSubmit={handleSubmit} className="space-y-6">
                        <div className="form-group">
                            <label className="label flex items-center space-x-2">
                                <Mail className="w-4 h-4 text-blue-600" />
                                <span>Email Address</span>
                            </label>
                            <input
                                type="email"
                                required
                                className="input"
                                placeholder="your@email.com"
                                value={formData.email}
                                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                            />
                        </div>

                        <div className="form-group">
                            <label className="label flex items-center space-x-2">
                                <Lock className="w-4 h-4 text-blue-600" />
                                <span>Password</span>
                            </label>
                            <input
                                type="password"
                                required
                                className="input"
                                placeholder="••••••••"
                                value={formData.password}
                                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                            />
                        </div>

                        <button
                            type="submit"
                            disabled={loading}
                            className="btn-primary w-full flex items-center justify-center space-x-2 text-lg py-4"
                        >
                            {loading ? (
                                <>
                                    <div className="spinner w-5 h-5"></div>
                                    <span>Signing in...</span>
                                </>
                            ) : (
                                <>
                                    <Vote className="w-5 h-5" />
                                    <span>Sign In</span>
                                </>
                            )}
                        </button>
                    </form>

                    <div className="mt-6 text-center">
                        <p className="text-sm text-slate-600">
                            Don't have an account?{' '}
                            <Link to="/register" className="link font-semibold">
                                Sign up now
                            </Link>
                        </p>
                    </div>
                </div>

                {/* Demo Credentials */}
                <div className="mt-6 alert-info">
                    <p className="font-semibold mb-2 flex items-center space-x-2">
                        <Sparkles className="w-4 h-4" />
                        <span>Demo Credentials</span>
                    </p>
                    <p className="text-sm">Email: <code className="bg-blue-100 px-2 py-0.5 rounded">admin@test.com</code></p>
                    <p className="text-sm">Password: <code className="bg-blue-100 px-2 py-0.5 rounded">password123</code></p>
                </div>

                {/* Footer */}
                <p className="text-center text-sm text-slate-500 mt-8">
                    Secure, transparent, and democratic voting
                </p>
            </div>
        </div>
    );
}

