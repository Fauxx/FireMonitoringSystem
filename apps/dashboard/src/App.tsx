import { useState, useEffect, useMemo } from 'react';
import { MapLibreCanvas } from './components/MapLibreCanvas';
import { FloatingTopBar } from './components/FloatingTopBar';
import { SensorDrawer } from './components/SensorDrawer';
import { AlertsModal } from './components/modals/AlertsModal';
import { ProfileModal } from './components/modals/ProfileModal';
import { CommandCenterModal, type CommandCenterTab } from './components/modals/CommandCenterModal';
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
  const { initialSensors } = useDashboardData(isAuthenticated);
  const { sensors, publishCommand } = useLiveSensors(initialSensors);
  const [selectedSensorId, setSelectedSensorId] = useState<string | null>(null);
  const [flyToTrigger, setFlyToTrigger] = useState<{ id: string; ts: number } | null>(null);
  const [activeModal, setActiveModal] = useState<string | null>(null);

  const stats = useMemo(() => {
    const s = Object.values(sensors);
    let n = 0, w = 0, c = 0, off = 0;
    const now = Date.now();
    s.forEach(sensor => {
      // Treat devices with no updates for 15 minutes as Offline
      if (now - sensor.lastUpdated > 15 * 60 * 1000) {
        off++;
      } else if (sensor.status === 0) {
        n++;
      } else if (sensor.status === 1) {
        w++;
      } else if (sensor.status >= 2) {
        c++;
      }
    });
    return { total: s.length, normal: n, warning: w, critical: c, offline: off };
  }, [sensors]);

  const handleSearch = (id: string) => {
    if (sensors[id]) {
      setSelectedSensorId(id);
      setFlyToTrigger({ id, ts: Date.now() });
    } else {
      alert(`Sensor ${id} not found.`);
    }
  };

  return (
    <>
      <MapLibreCanvas 
        sensors={Object.values(sensors)} 
        onSensorSelect={setSelectedSensorId}
        flyToTrigger={flyToTrigger}
      />
      <FloatingTopBar onSearch={handleSearch} onOpenModal={setActiveModal} stats={stats} />
      <SensorDrawer 
        sensor={selectedSensorId ? sensors[selectedSensorId] : null} 
        onClose={() => setSelectedSensorId(null)} 
      />
      {/* Emergency Alerts Modal */}
      <AlertsModal 
        isOpen={activeModal === 'alerts'}
        onClose={() => setActiveModal(null)}
        sensors={sensors}
        onLocate={(id) => {
          setSelectedSensorId(id);
          setFlyToTrigger({ id, ts: Date.now() });
        }}
      />

      {/* Profile Settings Modal */}
      {activeModal === 'profile' && (
        <ProfileModal 
          isOpen={true} 
          onClose={() => setActiveModal(null)} 
        />
      )}

      {/* Unified Command Center Hub */}
      {activeModal && activeModal !== 'alerts' && activeModal !== 'profile' && (
        <CommandCenterModal 
          initialTab={
            activeModal === 'command-center' ? 'devices' :
            activeModal === 'system' ? 'observability' :
            activeModal === 'logs' ? 'incidents' :
            (activeModal as CommandCenterTab)
          }
          onClose={() => setActiveModal(null)}
          sensors={sensors}
          publishCommand={publishCommand}
          onLocate={(id) => {
            setSelectedSensorId(id);
            setFlyToTrigger({ id, ts: Date.now() });
          }}
        />
      )}
    </>
  );
}

export default App;
