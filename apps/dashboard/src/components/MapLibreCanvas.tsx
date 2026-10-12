import { useEffect, memo } from 'react';
import { MapContainer, TileLayer, Marker, useMap, Popup, Tooltip } from 'react-leaflet';
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

// Custom DivIcon with pointed pin needle and pulsing radar beacon
const createCustomIcon = (sensor: SensorState) => {
  const isOffline = Date.now() - sensor.lastUpdated > 15 * 60 * 1000;
  const status = isOffline ? -1 : sensor.status;
  
  const config = getStatusConfig(status);
  const isPulsing = status >= 1;
  const isCritical = status === 2;
  const isTransmitting = !isOffline && (Date.now() - sensor.lastUpdated < 60 * 1000);
  
  const html = `
    <div style="position: relative; width: 34px; height: 38px; display: flex; flex-direction: column; align-items: center; justify-content: flex-start; cursor: pointer;">
      ${(isPulsing || isTransmitting) ? `
        <div style="position: absolute; top: 12px; left: 50%; transform: translate(-50%, -50%); width: 28px; height: 28px; border-radius: 50%; background-color: ${config.hex}; opacity: 0.5; animation: beacon-wave ${isCritical ? '1s' : (isPulsing ? '1.4s' : '2.2s')} ease-out infinite;"></div>
      ` : ''}
      ${isCritical ? `
        <div style="position: absolute; top: 12px; left: 50%; transform: translate(-50%, -50%); width: 40px; height: 40px; border-radius: 50%; border: 2px solid ${config.hex}; opacity: 0.7; animation: beacon-wave 1s ease-out infinite;"></div>
      ` : ''}
      <div style="position: relative; z-index: 10; width: 24px; height: 24px; border-radius: 50%; border: 2px solid #ffffff; box-shadow: 0 0 12px ${config.hex}aa, 0 3px 6px rgba(0,0,0,0.5); background-color: ${config.hex}; display: flex; align-items: center; justify-content: center;">
        ${isCritical ? '<svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/></svg>' : (isPulsing ? '<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="white"><circle cx="12" cy="12" r="5"/></svg>' : '<div style="width: 7px; height: 7px; border-radius: 50%; background-color: white;"></div>')}
      </div>
      <!-- Pointer needle / bottom anchor tip pointing to exact coordinate -->
      <div style="position: relative; z-index: 9; width: 0; height: 0; border-left: 5px solid transparent; border-right: 5px solid transparent; border-top: 7px solid ${config.hex}; margin-top: -2px; filter: drop-shadow(0 2px 2px rgba(0,0,0,0.4));"></div>
    </div>
  `;
  
  return L.divIcon({
    html,
    className: '',
    iconSize: [34, 38],
    iconAnchor: [17, 31],
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
  }, [flyToTrigger, map]);

  return null;
}

const MemoizedSensorMarker = memo(({ sensor, onSelect }: { sensor: SensorState, onSelect: (id: string) => void }) => {
  const isOffline = Date.now() - sensor.lastUpdated > 15 * 60 * 1000;
  const config = getStatusConfig(isOffline ? -1 : sensor.status);

  return (
    <Marker
      position={[sensor.lat!, sensor.lon!]}
      icon={createCustomIcon(sensor)}
      eventHandlers={{
        click: () => onSelect(sensor.h_id)
      }}
    >
      <Tooltip direction="top" offset={[0, -28]} opacity={0.95} className="sensor-map-tooltip">
        <div className="flex flex-col gap-0.5">
          <div className="flex items-center gap-2 font-mono font-bold text-xs">
            <span>{sensor.h_id}</span>
            <span className={`text-[10px] uppercase font-semibold ${config.text}`}>
              ● {config.label}
            </span>
          </div>
          {sensor.temp != null && (
            <div className="text-[11px] text-gray-300 font-sans">
              {Number(sensor.temp).toFixed(1)}°C · {Number(sensor.smoke || 0).toFixed(0)} PPM
            </div>
          )}
        </div>
      </Tooltip>
      <Popup>
        <div className="p-1">
          <div className="text-sm font-mono font-bold text-gray-900">{sensor.h_id}</div>
          <div className="text-xs text-gray-600 mt-1">Status: {config.label}</div>
          {sensor.temp != null && (
            <div className="text-xs text-gray-700 mt-1 font-mono">
              Temp: {Number(sensor.temp).toFixed(1)}°C | Smoke: {Number(sensor.smoke || 0).toFixed(0)} PPM
            </div>
          )}
        </div>
      </Popup>
    </Marker>
  );
}, (prev, next) => {
  return (
    prev.sensor.h_id === next.sensor.h_id &&
    prev.sensor.status === next.sensor.status &&
    prev.sensor.lat === next.sensor.lat &&
    prev.sensor.lon === next.sensor.lon &&
    prev.sensor.temp === next.sensor.temp &&
    prev.sensor.smoke === next.sensor.smoke &&
    Math.floor(prev.sensor.lastUpdated / 60000) === Math.floor(next.sensor.lastUpdated / 60000)
  );
});

export function MapLibreCanvas({ sensors, flyToTrigger, onSensorSelect }: MapCanvasProps) {
  return (
    <div className="absolute inset-0 z-0 bg-base-dark">
      <MapContainer
        center={[14.5995, 120.9842]}
        zoom={13}
        style={{ width: '100%', height: '100%', backgroundColor: '#111827' }}
        zoomControl={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        
        <MapController flyToTrigger={flyToTrigger} sensors={sensors} />
        
        {sensors.map(sensor => {
          const lat = Number(sensor.lat);
          const lon = Number(sensor.lon);
          if (sensor.lat == null || sensor.lon == null || isNaN(lat) || isNaN(lon)) return null;
          return (
            <MemoizedSensorMarker 
              key={sensor.h_id} 
              sensor={{ ...sensor, lat, lon }} 
              onSelect={onSensorSelect} 
            />
          );
        })}
      </MapContainer>
    </div>
  );
}
