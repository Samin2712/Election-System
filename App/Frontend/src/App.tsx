import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from './store/authStore';

// Pages
import Login from './pages/Login';
import Register from './pages/Register';
import Dashboard from './pages/Dashboard';
import Organizations from './pages/Organizations';
import Elections from './pages/Elections';
import ElectionDetails from './pages/ElectionDetails';
import VoterPortal from './pages/VoterPortal';
import Results from './pages/Results';
import ResultsDashboard from './pages/ResultsDashboard';
import UserProfile from './pages/UserProfile';

// Layout
import Layout from './components/Layout';

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  return isAuthenticated ? <>{children}</> : <Navigate to="/login" />;
}

function App() {
  return (
    <BrowserRouter>
      <Toaster position="top-right" />
      <Routes>
        {/* Public Routes */}
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />

        {/* Private Routes */}
        <Route
          path="/"
          element={
            <PrivateRoute>
              <Layout />
            </PrivateRoute>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="organizations" element={<Organizations />} />
          <Route path="elections" element={<Elections />} />
          <Route path="elections/:id" element={<ElectionDetails />} />
          <Route path="vote" element={<VoterPortal />} />
          <Route path="results/:electionId/:raceId" element={<Results />} />
          <Route path="results/:electionId" element={<ResultsDashboard />} />
          <Route path="profile" element={<UserProfile />} />
        </Route>

        {/* Catch all */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
