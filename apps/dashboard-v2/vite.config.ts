import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    proxy: {
      '/api': {
        target: process.env.API_URL || 'http://api:8000',
        changeOrigin: true,
      },
      '/auth': {
        target: process.env.API_URL || 'http://api:8000',
        changeOrigin: true,
      },
      '/protected': {
        target: 'http://dashboard:8080',
        changeOrigin: true,
      },
      '/grafana': {
        target: process.env.GRAFANA_URL || 'http://grafana:3000',
        changeOrigin: true,
        configure: (proxy, _options) => {
          proxy.on('proxyReq', (proxyReq, _req, _res) => {
            proxyReq.setHeader('X-WEBAUTH-USER', 'admin');
            proxyReq.setHeader('X-WEBAUTH-ROLE', 'Admin');
          });
        }
      }
    }
  }
})
