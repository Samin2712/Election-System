import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams, Link } from 'react-router-dom';
import { Vote, CheckCircle, AlertCircle, Loader, Mail, Lock, User, Building2, LogOut } from 'lucide-react';
import toast from 'react-hot-toast';
import { invitationsApi } from '@/lib/api';
import { useAuthStore } from '@/store/authStore';
import type { InvitationValidation } from '@/types';

type PageState = 'loading' | 'valid' | 'invalid' | 'expired' | 'login-required' | 'register' | 'success' | 'wrong-account';

export default function InvitePage() {
    const [searchParams] = useSearchParams();
    const navigate = useNavigate();
    const { user, isAuthenticated, logout, refreshUserOrganizations } = useAuthStore();

    const [pageState, setPageState] = useState<PageState>('loading');
    const [invitation, setInvitation] = useState<InvitationValidation | null>(null);
    const [processing, setProcessing] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Registration form state
    const [regForm, setRegForm] = useState({
        username: '',
        email: '',
        password: '',
        confirmPassword: '',
    });
    const [formErrors, setFormErrors] = useState<{ [key: string]: string }>({});

    const token = searchParams.get('token');

    useEffect(() => {
        if (!token) {
            setPageState('invalid');
            setError('No invitation token provided');
            return;
        }

        validateToken();
    }, [token]);

    const validateToken = async () => {
        try {
            const result = await invitationsApi.validateToken(token!);
            setInvitation(result);

            if (!result.valid) {
                setPageState('expired');
                return;
            }

            if (result.user_exists) {
                if (isAuthenticated && user) {
                    // Check if logged-in user's email matches invite email
                    if (user.email.toLowerCase() === result.email.toLowerCase()) {
                        // Same user - can auto accept
                        setPageState('valid');
                    } else {
                        // Different user logged in - show warning
                        setPageState('wrong-account');
                    }
                } else {
                    // User exists but not logged in
                    setPageState('login-required');
                }
            } else {
                // New user - show registration
                // Clear any existing session first
                if (isAuthenticated) {
                    logout();
                }
                setRegForm(prev => ({ ...prev, email: result.email }));
                setPageState('register');
            }
        } catch (err: any) {
            setPageState('invalid');
            setError(err.response?.data?.error || 'Invalid or expired invitation');
        }
    };

    const handleAcceptInvitation = async () => {
        if (!token) return;

        setProcessing(true);
        try {
            const result = await invitationsApi.accept(token);
            await refreshUserOrganizations();
            setPageState('success');
            toast.success(`Joined ${result.organization.name} successfully!`);
            
            // Redirect to dashboard after 2 seconds
            setTimeout(() => {
                navigate('/dashboard');
            }, 2000);
        } catch (err: any) {
            toast.error(err.response?.data?.error || 'Failed to accept invitation');
            setError(err.response?.data?.error || 'Failed to accept invitation');
        } finally {
            setProcessing(false);
        }
    };

    const validateRegForm = (): boolean => {
        const errors: { [key: string]: string } = {};

        if (!regForm.username.trim()) {
            errors.username = 'Username is required';
        } else if (regForm.username.length < 3) {
            errors.username = 'Username must be at least 3 characters';
        }

        if (!regForm.password) {
            errors.password = 'Password is required';
        } else if (regForm.password.length < 8) {
            errors.password = 'Password must be at least 8 characters';
        }

        if (!regForm.confirmPassword) {
            errors.confirmPassword = 'Please confirm your password';
        } else if (regForm.password !== regForm.confirmPassword) {
            errors.confirmPassword = 'Passwords do not match';
        }

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleRegister = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!validateRegForm() || !token) return;

        setProcessing(true);
        try {
            const result = await invitationsApi.registerWithInvite({
                token,
                username: regForm.username,
                email: regForm.email,
                password: regForm.password,
            });

            if (result.ok && result.accessToken) {
                // IMPORTANT: Clear ALL old session data first
                logout();
                localStorage.clear();
                
                // Set new tokens
                localStorage.setItem('accessToken', result.accessToken);
                localStorage.setItem('refreshToken', result.refreshToken || '');
                
                setPageState('success');
                toast.success(`Welcome to ${result.organization.name}!`);

                // Force full page reload to clear all cached state
                setTimeout(() => {
                    window.location.href = '/dashboard';
                }, 2000);
            }
        } catch (err: any) {
            toast.error(err.response?.data?.error || 'Registration failed');
            setFormErrors({ submit: err.response?.data?.error || 'Registration failed' });
        } finally {
            setProcessing(false);
        }
    };

    const handleFormChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const { name, value } = e.target;
        setRegForm(prev => ({ ...prev, [name]: value }));
        if (formErrors[name]) {
            setFormErrors(prev => ({ ...prev, [name]: '' }));
        }
    };

    // Render based on page state
    return (
        <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center px-4 py-8">
            <div className="max-w-md w-full">
                {/* Logo */}
                <div className="text-center mb-8">
                    <div className="inline-flex items-center justify-center w-16 h-16 bg-gradient-to-br from-blue-600 to-indigo-600 rounded-2xl mb-4 shadow-lg">
                        <Vote className="w-10 h-10 text-white" />
                    </div>
                </div>

                {/* Loading State */}
                {pageState === 'loading' && (
                    <div className="card text-center py-12">
                        <Loader className="w-12 h-12 text-blue-600 animate-spin mx-auto mb-4" />
                        <h2 className="text-xl font-semibold text-slate-900">Validating Invitation...</h2>
                        <p className="text-slate-600 mt-2">Please wait while we verify your invitation.</p>
                    </div>
                )}

                {/* Invalid Token */}
                {pageState === 'invalid' && (
                    <div className="card text-center py-12">
                        <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                            <AlertCircle className="w-8 h-8 text-red-600" />
                        </div>
                        <h2 className="text-xl font-semibold text-slate-900">Invalid Invitation</h2>
                        <p className="text-slate-600 mt-2">{error || 'This invitation link is not valid.'}</p>
                        <Link to="/login" className="btn-primary mt-6 inline-block">
                            Go to Login
                        </Link>
                    </div>
                )}

                {/* Expired Token */}
                {pageState === 'expired' && (
                    <div className="card text-center py-12">
                        <div className="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-4">
                            <AlertCircle className="w-8 h-8 text-yellow-600" />
                        </div>
                        <h2 className="text-xl font-semibold text-slate-900">Invitation Expired</h2>
                        <p className="text-slate-600 mt-2">
                            This invitation has expired. Please contact the organization administrator for a new invitation.
                        </p>
                        <Link to="/login" className="btn-primary mt-6 inline-block">
                            Go to Login
                        </Link>
                    </div>
                )}

                {/* User Exists - Need to Login */}
                {pageState === 'login-required' && invitation && (
                    <div className="card py-8">
                        <div className="text-center mb-6">
                            <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                                <Building2 className="w-8 h-8 text-blue-600" />
                            </div>
                            <h2 className="text-xl font-semibold text-slate-900">Join {invitation.organization.name}</h2>
                            <p className="text-slate-600 mt-2">
                                You've been invited as <span className="font-semibold text-blue-600">{invitation.role}</span>
                            </p>
                        </div>

                        <div className="bg-slate-50 rounded-xl p-4 mb-6">
                            <div className="flex items-center space-x-3">
                                <Mail className="w-5 h-5 text-slate-600" />
                                <div>
                                    <p className="text-sm text-slate-600">Invitation sent to</p>
                                    <p className="font-medium text-slate-900">{invitation.email}</p>
                                </div>
                            </div>
                        </div>

                        <p className="text-center text-slate-700 mb-6">
                            An account with this email already exists. Please log in to accept the invitation.
                        </p>

                        <Link 
                            to={`/login?redirect=/invite?token=${token}`}
                            className="btn-primary w-full text-center block"
                        >
                            Log In to Accept
                        </Link>
                    </div>
                )}

                {/* Wrong Account Logged In */}
                {pageState === 'wrong-account' && invitation && (
                    <div className="card py-8">
                        <div className="text-center mb-6">
                            <div className="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-4">
                                <AlertCircle className="w-8 h-8 text-yellow-600" />
                            </div>
                            <h2 className="text-xl font-semibold text-slate-900">Wrong Account</h2>
                            <p className="text-slate-600 mt-2">
                                You're logged in with a different account
                            </p>
                        </div>

                        <div className="space-y-3 mb-6">
                            <div className="bg-red-50 rounded-xl p-4">
                                <div className="flex items-center space-x-3">
                                    <LogOut className="w-5 h-5 text-red-600" />
                                    <div>
                                        <p className="text-sm text-red-600">Currently logged in as</p>
                                        <p className="font-medium text-red-800">{user?.email}</p>
                                    </div>
                                </div>
                            </div>
                            
                            <div className="bg-green-50 rounded-xl p-4">
                                <div className="flex items-center space-x-3">
                                    <Mail className="w-5 h-5 text-green-600" />
                                    <div>
                                        <p className="text-sm text-green-600">Invitation sent to</p>
                                        <p className="font-medium text-green-800">{invitation.email}</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <p className="text-center text-slate-600 text-sm mb-6">
                            Please log out and log in with <strong>{invitation.email}</strong> to accept this invitation.
                        </p>

                        <button
                            onClick={() => {
                                logout();
                                window.location.href = `/login?redirect=/invite?token=${token}`;
                            }}
                            className="btn-primary w-full flex items-center justify-center space-x-2"
                        >
                            <LogOut className="w-5 h-5" />
                            <span>Log Out & Switch Account</span>
                        </button>
                    </div>
                )}

                {/* Logged In - Accept Invitation */}
                {pageState === 'valid' && invitation && isAuthenticated && (
                    <div className="card py-8">
                        <div className="text-center mb-6">
                            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                                <Building2 className="w-8 h-8 text-green-600" />
                            </div>
                            <h2 className="text-xl font-semibold text-slate-900">Join {invitation.organization.name}</h2>
                            <p className="text-slate-600 mt-2">
                                You've been invited as <span className="font-semibold text-blue-600">{invitation.role}</span>
                            </p>
                        </div>

                        <div className="bg-slate-50 rounded-xl p-4 mb-6">
                            <div className="flex items-center space-x-3">
                                <Mail className="w-5 h-5 text-slate-600" />
                                <div>
                                    <p className="text-sm text-slate-600">Logged in as</p>
                                    <p className="font-medium text-slate-900">{user?.email || invitation.email}</p>
                                </div>
                            </div>
                        </div>

                        <button
                            onClick={handleAcceptInvitation}
                            disabled={processing}
                            className="btn-primary w-full flex items-center justify-center space-x-2"
                        >
                            {processing ? (
                                <>
                                    <Loader className="w-5 h-5 animate-spin" />
                                    <span>Joining...</span>
                                </>
                            ) : (
                                <>
                                    <CheckCircle className="w-5 h-5" />
                                    <span>Accept Invitation</span>
                                </>
                            )}
                        </button>

                        {error && (
                            <p className="mt-4 text-center text-red-600 text-sm">{error}</p>
                        )}
                    </div>
                )}

                {/* New User - Registration Form */}
                {pageState === 'register' && invitation && (
                    <div className="card py-8">
                        <div className="text-center mb-6">
                            <h2 className="text-2xl font-bold text-slate-900">Create Your Account</h2>
                            <p className="text-slate-600 mt-2">
                                Join <span className="font-semibold text-blue-600">{invitation.organization.name}</span>
                            </p>
                        </div>

                        <form onSubmit={handleRegister} className="space-y-5">
                            {/* Email (Pre-filled, read-only) */}
                            <div className="form-group">
                                <label className="label flex items-center space-x-2">
                                    <Mail className="w-4 h-4" />
                                    <span>Email</span>
                                </label>
                                <input
                                    type="email"
                                    value={regForm.email}
                                    readOnly
                                    className="input bg-slate-100 cursor-not-allowed"
                                />
                                <p className="text-xs text-slate-500 mt-1">
                                    This email is linked to your invitation
                                </p>
                            </div>

                            {/* Username */}
                            <div className="form-group">
                                <label className="label flex items-center space-x-2">
                                    <User className="w-4 h-4" />
                                    <span>Username</span>
                                </label>
                                <input
                                    type="text"
                                    name="username"
                                    required
                                    className={`input ${formErrors.username ? 'border-red-500' : ''}`}
                                    placeholder="johndoe"
                                    value={regForm.username}
                                    onChange={handleFormChange}
                                />
                                {formErrors.username && (
                                    <p className="text-red-500 text-sm mt-1">{formErrors.username}</p>
                                )}
                            </div>

                            {/* Password */}
                            <div className="form-group">
                                <label className="label flex items-center space-x-2">
                                    <Lock className="w-4 h-4" />
                                    <span>Password</span>
                                </label>
                                <input
                                    type="password"
                                    name="password"
                                    required
                                    className={`input ${formErrors.password ? 'border-red-500' : ''}`}
                                    placeholder="••••••••"
                                    value={regForm.password}
                                    onChange={handleFormChange}
                                />
                                {formErrors.password && (
                                    <p className="text-red-500 text-sm mt-1">{formErrors.password}</p>
                                )}
                            </div>

                            {/* Confirm Password */}
                            <div className="form-group">
                                <label className="label flex items-center space-x-2">
                                    <Lock className="w-4 h-4" />
                                    <span>Confirm Password</span>
                                </label>
                                <input
                                    type="password"
                                    name="confirmPassword"
                                    required
                                    className={`input ${formErrors.confirmPassword ? 'border-red-500' : ''}`}
                                    placeholder="••••••••"
                                    value={regForm.confirmPassword}
                                    onChange={handleFormChange}
                                />
                                {formErrors.confirmPassword && (
                                    <p className="text-red-500 text-sm mt-1">{formErrors.confirmPassword}</p>
                                )}
                            </div>

                            {formErrors.submit && (
                                <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
                                    {formErrors.submit}
                                </div>
                            )}

                            <button
                                type="submit"
                                disabled={processing}
                                className="btn-primary w-full flex items-center justify-center space-x-2"
                            >
                                {processing ? (
                                    <>
                                        <Loader className="w-5 h-5 animate-spin" />
                                        <span>Creating Account...</span>
                                    </>
                                ) : (
                                    <>
                                        <CheckCircle className="w-5 h-5" />
                                        <span>Create Account & Join</span>
                                    </>
                                )}
                            </button>
                        </form>

                        <p className="text-center text-slate-600 mt-6">
                            Already have an account?{' '}
                            <Link to={`/login?redirect=/invite?token=${token}`} className="text-blue-600 font-semibold hover:underline">
                                Log in
                            </Link>
                        </p>
                    </div>
                )}

                {/* Success State */}
                {pageState === 'success' && invitation && (
                    <div className="card text-center py-12">
                        <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6">
                            <CheckCircle className="w-10 h-10 text-green-600" />
                        </div>
                        <h2 className="text-2xl font-bold text-slate-900">Welcome!</h2>
                        <p className="text-slate-600 mt-2">
                            You've successfully joined <span className="font-semibold">{invitation.organization.name}</span>
                        </p>
                        <p className="text-slate-500 mt-4">Redirecting to dashboard...</p>
                        <Loader className="w-6 h-6 text-blue-600 animate-spin mx-auto mt-4" />
                    </div>
                )}
            </div>
        </div>
    );
}
