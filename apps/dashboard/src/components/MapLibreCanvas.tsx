import { useEffect, memo } from 'react';
import { MapContainer, TileLayer, Marker, useMap, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { SensorState } from '../types';
import { getStatusConfig } from '../utils/statusColors';

// Fix for default Leaflet icons
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

interface MapCanvasProps {
  sensors: SensorState[];
  flyToTrigger?: { id: string; ts: number } | null;
  onSensorSelect: (id: string) => void;
}

// Custom DivIcon for our sensors
const createCustomIcon = (status: number) => {
  const config = getStatusConfig(status);
  const isCritical = status === 2;
  
  const html = `
    <div style="position: relative; display: flex; align-items: center; justify-content: center; width: 100%; height: 100%;">
      ${isCritical ? '<div style="position: absolute; border-radius: 50%; width: 48px; height: 48px; background-color: var(--color-primary); opacity: 0.6; animation: ping 1.5s cubic-bezier(0, 0, 0.2, 1) infinite;"></div>' : ''}
      <div style="position: relative; z-index: 10; width: 20px; height: 20px; border-radius: 50%; border: 2px solid white; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1); background-color: ${config.hex}; display: flex; align-items: center; justify-content: center;">
        ${isCritical ? '<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/></svg>' : ''}
      </div>
    </div>
  `;
  
  return L.divIcon({
    html,
    className: '',
    iconSize: [20, 20],
    iconAnchor: [10, 10],
  });
};

function MapController({ flyToTrigger, sensors }: { flyToTrigger: { id: string; ts: number } | null | undefined, sensors: SensorState[] }) {
  const map = useMap();
  
  useEffect(() => {
    if (flyToTrigger) {
      const sensor = sensors.find(s => s.h_id === flyToTrigger.id);
      if (sensor && sensor.lat != null && sensor.lon != null) {
        map.flyTo([sensor.lat, sensor.lon], 16, {
          duration: 1.5
        });
      }
    }
  }, [flyToTrigger, map]); // Removed sensors to prevent re-panning on every telemetry tick

  return null;
}

const MemoizedSensorMarker = memo(({ sensor, onSelect }: { sensor: SensorState, onSelect: (id: string) => void }) => {
  return (
    <Marker
      position={[sensor.lat, sensor.lon]}
      icon={createCustomIcon(sensor.status)}
      eventHandlers={{
        click: () => onSelect(sensor.h_id)
      }}
    >
      <Popup>
        <div className="text-sm font-mono font-bold text-gray-900">{sensor.h_id}</div>
      </Popup>
    </Marker>
  );
}, (prev, next) => prev.sensor === next.sensor);

export function MapLibreCanvas({ sensors, flyToTrigger, onSensorSelect }: MapCanvasProps) {
  return (
    <div className="absolute inset-0 z-0 bg-base-dark">
      <MapContainer
        center={[14.5995, 120.9842]}
        zoom={11}
        style={{ width: '100%', height: '100%', backgroundColor: '#111827' }}
        zoomControl={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        
        <MapController flyToTrigger={flyToTrigger} sensors={sensors} />
        
        {sensors.map(sensor => {
          if (sensor.lat == null || sensor.lon == null || isNaN(sensor.lat)) return null;
          return (
            <MemoizedSensorMarker 
              key={`${sensor.h_id}-${sensor.status}`} 
              sensor={sensor} 
              onSelect={onSensorSelect} 
            />
          );
        })}
      </MapContainer>
    </div>
  );
}
