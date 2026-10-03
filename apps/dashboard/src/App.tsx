import { useState, useEffect, useMemo } from 'react';
import { MapLibreCanvas } from './components/MapLibreCanvas';
import { FloatingTopBar } from './components/FloatingTopBar';
import { SensorDrawer } from './components/SensorDrawer';
import { AlertSnackbar } from './components/AlertSnackbar';
import { LoginOverlay } from './components/LoginOverlay';
import { useLiveSensors } from './hooks/useLiveSensors';
import { useDashboardData } from './hooks/useDashboardData';
import { DevicesModal } from './components/modals/DevicesModal';
import { AnalyticsModal } from './components/modals/AnalyticsModal';
import { LogsModal } from './components/modals/LogsModal';
import { SimulatorModal } from "./components/modals/SimulatorModal";
import { ExportModal } from './components/modals/ExportModal';

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
  const { initialSensors } = useDashboardData(isAuthenticated);
  const { sensors, activeAlert, clearAlert, publishCommand } = useLiveSensors(initialSensors);
  const [selectedSensorId, setSelectedSensorId] = useState<string | null>(null);
  const [activeModal, setActiveModal] = useState<string | null>(null);

  const stats = useMemo(() => {
    const s = Object.values(sensors);
    let n = 0, w = 0, c = 0;
    s.forEach(sensor => {
      if (sensor.status === 0) n++;
      else if (sensor.status === 1) w++;
      else if (sensor.status >= 2) c++;
    });
    return { total: s.length, normal: n, warning: w, critical: c };
  }, [sensors]);

  const handleSearch = (id: string) => {
    if (sensors[id]) {
      setSelectedSensorId(id);
    } else {
      alert(`Sensor ${id} not found.`);
    }
  };

  return (
    <>
      <MapLibreCanvas 
        sensors={Object.values(sensors)} 
        selectedSensorId={selectedSensorId}
        onSensorSelect={setSelectedSensorId}
      />
      <FloatingTopBar onSearch={handleSearch} onOpenModal={setActiveModal} stats={stats} />
      <SensorDrawer 
        sensor={selectedSensorId ? sensors[selectedSensorId] : null} 
        onClose={() => setSelectedSensorId(null)} 
      />
      <AlertSnackbar 
        alert={activeAlert} 
        onView={(id) => { setSelectedSensorId(id); clearAlert(); }} 
        onDismiss={clearAlert}
      />
      
      {/* Modals */}
      {activeModal === 'devices' && <DevicesModal sensors={Object.values(sensors)} onClose={() => setActiveModal(null)} />}
      {activeModal === 'analytics' && <AnalyticsModal onClose={() => setActiveModal(null)} />}
      {activeModal === 'system' && <AnalyticsModal onClose={() => setActiveModal(null)} />}
      {activeModal === 'logs' && <LogsModal onClose={() => setActiveModal(null)} />}
      {activeModal === 'export' && <ExportModal onClose={() => setActiveModal(null)} />}
      {activeModal === 'simulator' && <SimulatorModal sensors={sensors} publishCommand={publishCommand} onClose={() => setActiveModal(null)} />}
    </>
  );
}

export default App;
