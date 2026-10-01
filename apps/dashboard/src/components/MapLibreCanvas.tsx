import { useEffect, useRef } from 'react';
import Map, { Marker, NavigationControl } from 'react-map-gl/maplibre';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { SensorState } from '../types';
import { getStatusConfig } from '../utils/statusColors';
import { Flame } from 'lucide-react';

interface MapCanvasProps {
  sensors: SensorState[];
  selectedSensorId: string | null;
  onSensorSelect: (id: string) => void;
}

export function MapLibreCanvas({ sensors, selectedSensorId, onSensorSelect }: MapCanvasProps) {
  const mapRef = useRef<any>(null);

  // Handle flying to the selected sensor
  useEffect(() => {
    if (selectedSensorId && mapRef.current) {
      const sensor = sensors.find(s => s.h_id === selectedSensorId);
      if (sensor) {
        mapRef.current.flyTo({
          center: [sensor.lon, sensor.lat],
          zoom: 17, // Zoom in tight to the street!
          pitch: 45, // Tilt the camera for a 3D effect
          duration: 2000,
          essential: true
        });
      }
    }
  }, [selectedSensorId]); // Only trigger when selected sensor changes

  return (
    <div className="absolute inset-0 z-0 bg-base-dark">
      <Map
        ref={mapRef}
        style={{ width: '100%', height: '100%' }}
        initialViewState={{
          longitude: 120.9842,
          latitude: 14.5995,
          zoom: 4.5, // Start zoomed in enough to clearly focus on the Philippines
          pitch: 0,
        }}
        // Force globe projection regardless of style
        projection={{ type: "globe" } as any}
        
        // Using OpenFreeMap's standard bright (Liberty) style
        mapStyle="https://tiles.openfreemap.org/styles/liberty"
        
        // This is the magic! At low zoom it's a globe, at high zoom it flattens to vector streets.
        onLoad={(e) => {
          const map = e.target;
          
          // Enable globe projection natively
          if (map.setProjection) {
            map.setProjection({ type: 'globe' });
          }
          
          // Find the lowest text label layer to insert buildings beneath it
          const layers = map.getStyle().layers;
          let labelLayerId;
          for (let i = 0; i < layers.length; i++) {
            const layer = layers[i];
            if (layer.type === 'symbol' && layer.layout && (layer.layout as any)['text-field']) {
              labelLayerId = layer.id;
              break;
            }
          }

          // Inject the 3D buildings layer using OpenFreeMap's underlying vector data
          map.addLayer(
            {
              id: '3d-buildings',
              source: 'openmaptiles',
              'source-layer': 'building',
              type: 'fill-extrusion',
              minzoom: 14,
              paint: {
                'fill-extrusion-color': '#e2e8f0', // Light slate so they pop against the dark map
                'fill-extrusion-height': ['get', 'render_height'],
                'fill-extrusion-base': ['get', 'render_min_height'],
                'fill-extrusion-opacity': 0.85 // High opacity for clear visibility
              }
            },
            labelLayerId
          );
        }}
      >
        {/* Zoom +/- buttons & compass */}
        <NavigationControl position="top-right" />

        {sensors.map((sensor) => {
          const config = getStatusConfig(sensor.status);
          const isCritical = sensor.status === 2;
          
          return (
            <Marker
              key={sensor.h_id}
              longitude={sensor.lon}
              latitude={sensor.lat}
              anchor="center"
              onClick={e => {
                e.originalEvent.stopPropagation();
                onSensorSelect(sensor.h_id);
              }}
            >
              <div className="relative flex items-center justify-center cursor-pointer group">
                
                {/* Expandable CSS Shockwave for Critical Alerts */}
                {isCritical && (
                  <div 
                    className="absolute inset-0 rounded-full animate-ping bg-primary opacity-60" 
                    style={{ width: '48px', height: '48px', left: '-14px', top: '-14px', animationDuration: '1.5s' }} 
                  />
                )}
                
                {/* The actual dot */}
                <div 
                  className="relative z-10 w-5 h-5 rounded-full border-2 border-surface shadow-lg flex items-center justify-center transition-transform group-hover:scale-125"
                  style={{ backgroundColor: config.hex }}
                >
                  {isCritical && <Flame className="w-3 h-3 text-white" strokeWidth={3} />}
                </div>

                {/* Always-on label for critical items, hover label for normal */}
                <div className={`absolute top-6 whitespace-nowrap px-2 py-1 bg-black/80 backdrop-blur-sm rounded text-[10px] text-white font-mono transition-opacity border border-surface-border ${isCritical ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'}`}>
                  {sensor.h_id}
                </div>
              </div>
            </Marker>
          );
        })}
      </Map>
    </div>
  );
}
