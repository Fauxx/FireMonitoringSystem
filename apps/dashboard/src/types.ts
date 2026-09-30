export interface SensorTelemetry {
  h_id: string;
  lat: number;
  lon: number;
  status: number; // 0: Normal, 1: Warning, 2: Critical
  temp?: number;
  smoke?: number;
  flame?: number;
  _time?: string;
}

export interface SensorState extends SensorTelemetry {
  lastUpdated: number;
}
