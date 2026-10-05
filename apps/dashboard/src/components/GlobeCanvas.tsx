import { useEffect, useRef, useState, useMemo } from 'react';
import Globe from 'react-globe.gl';
import type { SensorState } from '../types';
import { getStatusConfig } from '../utils/statusColors';

interface GlobeCanvasProps {
  sensors: SensorState[];
  selectedSensorId: string | null;
  onSensorSelect: (id: string) => void;
}

export function GlobeCanvas({ sensors, selectedSensorId, onSensorSelect }: GlobeCanvasProps) {
  const globeRef = useRef<any>(null);
  const [dimensions, setDimensions] = useState({ width: window.innerWidth, height: window.innerHeight });

  // Handle window resize dynamically
  useEffect(() => {
    const handleResize = () => setDimensions({ width: window.innerWidth, height: window.innerHeight });
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Map our sensor data to globe.gl data format
  const pointsData = useMemo(() => {
    return sensors.map(s => {
      const config = getStatusConfig(s.status);
      return {
        lat: s.lat,
        lng: s.lon,
        size: s.status === 2 ? 0.3 : (s.status === 1 ? 0.2 : 0.1), // Larger for critical/warning
        status: s.status,
        color: config.hex,
        id: s.h_id,
        label: `
          <div style="background: rgba(0,0,0,0.8); padding: 8px; border-radius: 4px; border: 1px solid ${config.hex}; font-family: sans-serif;">
            <strong style="color: white; display: block; margin-bottom: 4px;">${s.h_id}</strong>
            <span style="color: ${config.hex}; font-size: 12px; text-transform: uppercase;">${config.label}</span>
          </div>
        `,
      };
    });
  }, [sensors]);

  useEffect(() => {
    // We use a small timeout to ensure the globe's WebGL context is fully initialized
    const timer = setTimeout(() => {
      if (globeRef.current && globeRef.current.pointOfView) {
        if (selectedSensorId) {
          const sensor = sensors.find(s => s.h_id === selectedSensorId);
          if (sensor) {
            globeRef.current.pointOfView({ lat: sensor.lat, lng: sensor.lon, altitude: 0.05 }, 1500);
          }
        } else {
          // Default view: Hover closely over Manila (Philippines)
          globeRef.current.pointOfView({ lat: 14.5995, lng: 120.9842, altitude: 0.15 }, 2000);
        }
      }
    }, 100);
    return () => clearTimeout(timer);
  }, [selectedSensorId, sensors]);

  return (
    <div className="absolute inset-0 z-0 bg-base-dark flex items-center justify-center">
      {/* We use standard Earth textures provided by three-globe */}
      <Globe
        ref={globeRef}
        width={dimensions.width}
        height={dimensions.height}
        globeImageUrl="https://unpkg.com/three-globe/example/img/earth-night.jpg"
        backgroundImageUrl="https://unpkg.com/three-globe/example/img/night-sky.png"
        
        // Render sensors as glowing points on the globe
        pointsData={pointsData}
        pointLat="lat"
        pointLng="lng"
        pointColor="color"
        pointAltitude={0.01}
        pointRadius="size"
        pointsMerge={false}
        
        // HTML tooltips on hover
        pointLabel="label"
        
        // Handle clicks
        onPointClick={(point: any) => onSensorSelect(point.id)}
        
        // Rings for critical and warning items
        ringsData={pointsData.filter(p => p.status >= 1)}
        ringLat="lat"
        ringLng="lng"
        ringColor="color"
        ringMaxRadius={2}
        ringPropagationSpeed={3}
        ringRepeatPeriod={1000}
      />
    </div>
  );
}
