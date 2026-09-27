import { useState, useEffect } from 'react';
import { MapCanvas } from './components/MapCanvas';
import { FloatingTopBar } from './components/FloatingTopBar';
import { SensorDrawer } from './components/SensorDrawer';
import { AlertSnackbar } from './components/AlertSnackbar';
import { LoginOverlay } from './components/LoginOverlay';
import { useLiveSensors } from './hooks/useLiveSensors';
import { useDashboardData } from './hooks/useDashboardData';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);

  // Check initial auth status
  useEffect(() => {
    fetch('/auth/session')
      .then(res => {
        if (res.ok) setIsAuthenticated(true);
        else setIsAuthenticated(false);
      })
      .catch(() => setIsAuthenticated(false));
  }, []);

  return (
    <div className="relative w-screen h-screen overflow-hidden bg-gray-900 font-sans">
      
      {isAuthenticated === false && (
        <LoginOverlay onLoginSuccess={() => setIsAuthenticated(true)} />
      )}

      {/* When not authenticated (or checking), blur the background UI */}
      <div className={`w-full h-full transition-all duration-1000 ${isAuthenticated !== true ? 'blur-md opacity-60 pointer-events-none scale-105' : 'blur-0 opacity-100 scale-100'}`}>
        {/* Render Dashboard content only when authenticated to prevent unauthorized API calls failing, 
            OR we can render it empty and let the blur hide it. Let's render it if auth is null (checking) or true,
            but if false, we can still render it so the background exists to blur! 
            However, useDashboardData will fail with 401. That's fine, it will just show an empty map. */}
        <DashboardContent isAuthenticated={isAuthenticated === true} />
      </div>

    </div>
  );
}

// Extract dashboard content so hooks don't run aggressively if we don't want them to, 
// but we DO want the map to render in the background for the blur effect.
function DashboardContent({ isAuthenticated }: { isAuthenticated: boolean }) {
  // If not authenticated, we still call the hooks, but we might want to skip fetching.
  // We updated useDashboardData to handle errors gracefully.
  const { initialSensors, stats } = useDashboardData(isAuthenticated);
  const { sensors, activeAlert, clearAlert } = useLiveSensors(initialSensors);
  const [selectedSensorId, setSelectedSensorId] = useState<string | null>(null);

  const handleSearch = (id: string) => {
    if (sensors[id]) {
      setSelectedSensorId(id);
    } else {
      alert(`Sensor ${id} not found.`);
    }
  };

  return (
    <>
      <MapCanvas 
        sensors={Object.values(sensors)} 
        selectedSensorId={selectedSensorId}
        onSensorSelect={setSelectedSensorId}
      />
      <FloatingTopBar onSearch={handleSearch} stats={stats} />
      <SensorDrawer 
        sensor={selectedSensorId ? sensors[selectedSensorId] : null} 
        onClose={() => setSelectedSensorId(null)} 
      />
      <AlertSnackbar 
        alert={activeAlert} 
        onView={(id) => { setSelectedSensorId(id); clearAlert(); }} 
        onDismiss={clearAlert}
      />
    </>
  );
}

export default App;
