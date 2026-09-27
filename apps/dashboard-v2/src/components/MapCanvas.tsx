import { useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import type { SensorState } from '../types';
import { getStatusConfig } from '../utils/statusColors';
import 'leaflet/dist/leaflet.css';

// Fix Leaflet's default icon issue
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Create custom colored markers dynamically using SVG
const createCustomIcon = (hexColor: string, isCritical: boolean) => {
  const markerHtml = `
    <div style="
      background-color: ${hexColor};
      width: 24px;
      height: 24px;
      display: block;
      left: -12px;
      top: -12px;
      position: relative;
      border-radius: 3rem 3rem 0;
      transform: rotate(45deg);
      border: 2px solid white;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.5);
      ${isCritical ? 'animation: pulse 1s infinite;' : ''}
    "></div>
  `;

  return L.divIcon({
    className: 'custom-marker',
    html: markerHtml,
    iconSize: [24, 24],
    iconAnchor: [12, 24],
    popupAnchor: [0, -24],
  });
};

interface MapCanvasProps {
  sensors: SensorState[];
  selectedSensorId: string | null;
  onSensorSelect: (id: string) => void;
}

// Component to handle map flying when a sensor is selected
function MapFlyTo({ selectedSensor, sensors }: { selectedSensor: string | null, sensors: SensorState[] }) {
  const map = useMap();
  useEffect(() => {
    if (selectedSensor) {
      const sensor = sensors.find(s => s.h_id === selectedSensor);
      if (sensor) {
        map.flyTo([sensor.lat, sensor.lon], 16, { duration: 1.5 });
      }
    }
  }, [selectedSensor, map, sensors]);
  return null;
}

export function MapCanvas({ sensors, selectedSensorId, onSensorSelect }: MapCanvasProps) {
  // Center of Manila for default view
  const defaultCenter: [number, number] = [14.5995, 120.9842];

  return (
    <div className="absolute inset-0 z-0">
      <MapContainer
        center={defaultCenter}
        zoom={13}
        className="w-full h-full"
        zoomControl={false}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        
        <MapFlyTo selectedSensor={selectedSensorId} sensors={sensors} />

        {sensors.map((sensor) => {
          const config = getStatusConfig(sensor.status);
          const isCritical = sensor.status === 2;
          
          return (
            <Marker
              key={sensor.h_id}
              position={[sensor.lat, sensor.lon]}
              icon={createCustomIcon(config.hex, isCritical)}
              eventHandlers={{
                click: () => onSensorSelect(sensor.h_id),
              }}
            >
              <Popup className="rounded-lg shadow-lg">
                <div className="p-1">
                  <h3 className="font-bold text-sm mb-1">{sensor.h_id}</h3>
                  <div className={`text-xs font-semibold px-2 py-1 rounded text-white ${config.color}`}>
                    {config.label}
                  </div>
                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>
      
      {/* Add CSS for pulsing marker */}
      <style>{`
        @keyframes pulse {
          0% { transform: rotate(45deg) scale(1); box-shadow: 0 0 0 0 rgba(220, 38, 38, 0.7); }
          70% { transform: rotate(45deg) scale(1.1); box-shadow: 0 0 0 10px rgba(220, 38, 38, 0); }
          100% { transform: rotate(45deg) scale(1); box-shadow: 0 0 0 0 rgba(220, 38, 38, 0); }
        }
      `}</style>
    </div>
  );
}
