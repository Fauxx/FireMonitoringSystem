import { useState, useEffect, useMemo } from 'react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { X, Thermometer, Wind, AlertTriangle, CheckCircle, Flame } from 'lucide-react';
import type { SensorState } from '../types';
import { getStatusConfig } from '../utils/statusColors';

export function SensorDrawer({ sensor, onClose }: { sensor: SensorState | null, onClose: () => void }) {
  const [history, setHistory] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  // Mock historical data generation for the chart when a sensor is clicked
  useEffect(() => {
    if (sensor) {
      setLoading(true);
      setTimeout(() => {
        const mockData = Array.from({ length: 20 }).map((_, i) => ({
          time: new Date(Date.now() - (20 - i) * 60000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          temp: 30 + Math.random() * (sensor.status === 2 ? 50 : 10)
        }));
        setHistory(mockData);
        setLoading(false);
      }, 600);
    }
  }, [sensor?.h_id]);

  // Live update the chart with the current reading
  const chartData = useMemo(() => {
    if (!history.length || !sensor?.temp) return history;
    const newData = {
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      temp: sensor.temp
    };
    return [...history.slice(1), newData];
  }, [history, sensor?.temp]);

  if (!sensor) return null;

  const config = getStatusConfig(sensor.status);

  return (
    <div className="absolute top-6 bottom-6 right-6 w-96 bg-white/40 backdrop-blur-3xl rounded-none shadow-[0_8px_32px_0_rgba(31,38,135,0.07)] border border-white/60 z-[1000] flex flex-col overflow-hidden pointer-events-auto transition-transform duration-500 transform translate-x-0">
      
      {/* Header */}
      <div className="p-6 border-b border-white/40 flex justify-between items-start bg-white/20">
        <div>
          <div className="w-8 h-px bg-black mb-3"></div>
          <p className="text-[9px] font-normal text-gray-500 tracking-[0.2em] uppercase mb-1">Telemetry Node</p>
          <h2 className="text-2xl font-light text-black">{sensor.h_id}</h2>
        </div>
        <button onClick={onClose} className="p-2 hover:bg-white/50 transition-colors text-gray-500 hover:text-black rounded-none">
          <X className="w-5 h-5" strokeWidth={1} />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-8 no-scrollbar">
        
        {/* Status Block */}
        <div className="bg-white/30 p-6 mb-10 border border-white/50 backdrop-blur-sm">
          <div className="flex items-center gap-4 mb-3">
            <div className={`p-2 border ${sensor.status === 2 ? 'border-red-500 text-red-500' : 'border-black text-black'}`}>
              {sensor.status === 2 ? <AlertTriangle className="w-4 h-4" strokeWidth={1.5} /> : <CheckCircle className="w-4 h-4" strokeWidth={1.5} />}
            </div>
            <div>
              <p className="text-[9px] text-gray-500 font-normal uppercase tracking-[0.2em] mb-1">State Vector</p>
              <p className={`font-light text-xl tracking-wide ${config.text}`}>{config.label}</p>
            </div>
          </div>
          <p className="text-[9px] text-gray-400 mt-4 uppercase tracking-widest border-t border-white/40 pt-3">
            SYNC: {new Date(sensor.lastUpdated).toLocaleTimeString()}
          </p>
        </div>

        {/* Live Metrics */}
        <h3 className="font-light text-black mb-4 text-[10px] tracking-[0.2em] uppercase flex items-center gap-2">
          <span className="w-2 h-2 bg-black inline-block"></span> Sensor Array
        </h3>
        
        <div className="grid grid-cols-2 gap-4 mb-10">
          <div className="bg-white/30 border border-white/50 p-5 backdrop-blur-sm hover:bg-white/40 transition-colors">
            <div className="flex items-center gap-3 mb-3">
              <Thermometer className="w-3.5 h-3.5 text-gray-500" strokeWidth={1.5} />
              <p className="text-[9px] text-gray-500 font-normal tracking-widest uppercase">Thermal</p>
            </div>
            <p className="text-2xl font-light text-black">{sensor.temp?.toFixed(1) || '--'}<span className="text-sm ml-1 text-gray-400">°C</span></p>
          </div>
          
          <div className="bg-white/30 border border-white/50 p-5 backdrop-blur-sm hover:bg-white/40 transition-colors">
            <div className="flex items-center gap-3 mb-3">
              <Wind className="w-3.5 h-3.5 text-gray-500" strokeWidth={1.5} />
              <p className="text-[9px] text-gray-500 font-normal tracking-widest uppercase">Particulate</p>
            </div>
            <p className="text-2xl font-light text-black">{sensor.smoke?.toFixed(0) || '--'}<span className="text-sm ml-1 text-gray-400">ppm</span></p>
          </div>
          
          <div className="bg-white/30 border border-white/50 p-5 col-span-2 backdrop-blur-sm hover:bg-white/40 transition-colors">
            <div className="flex items-center gap-3 mb-3">
              <Flame className="w-3.5 h-3.5 text-red-500" strokeWidth={1.5} />
              <p className="text-[9px] text-gray-500 font-normal tracking-widest uppercase">Combustion</p>
            </div>
            <div className="flex justify-between items-end">
              <p className="text-3xl font-light text-black">{sensor.flame?.toFixed(2) || '--'}</p>
              <div className="w-full max-w-[120px] h-1 bg-gray-200/50 relative ml-4 mb-2">
                <div 
                  className={`absolute top-0 left-0 h-full ${(sensor.flame || 0) > 0.5 ? 'bg-red-500' : 'bg-black'}`}
                  style={{ width: `${Math.min((sensor.flame || 0) * 100, 100)}%` }}
                ></div>
              </div>
            </div>
          </div>
        </div>

        {/* Chart */}
        <h3 className="font-light text-black mb-4 text-[10px] tracking-[0.2em] uppercase flex items-center gap-2">
          <span className="w-2 h-2 bg-black inline-block"></span> Thermal Trend
        </h3>
        
        <div className="h-52 w-full bg-white/20 border border-white/50 p-4 backdrop-blur-sm">
          {loading ? (
            <div className="w-full h-full flex items-center justify-center text-gray-400 text-[10px] tracking-widest uppercase font-light">
              Aggregating...
            </div>
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="colorTemp" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={config.hex} stopOpacity={0.3}/>
                    <stop offset="95%" stopColor={config.hex} stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <XAxis dataKey="time" hide />
                <YAxis domain={['auto', 'auto']} width={30} tick={{ fontSize: 9, fill: '#6b7280' }} axisLine={false} tickLine={false} />
                <Tooltip 
                  contentStyle={{ backgroundColor: 'rgba(255, 255, 255, 0.8)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255, 255, 255, 0.5)', borderRadius: '0', boxShadow: 'none' }}
                  labelStyle={{ fontWeight: '300', fontSize: '10px', color: '#000' }}
                  itemStyle={{ fontSize: '12px', color: '#000' }}
                />
                <Area type="monotone" dataKey="temp" stroke={config.hex} fillOpacity={1} fill="url(#colorTemp)" strokeWidth={1.5} isAnimationActive={false} />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </div>

      </div>
    </div>
  );
}
