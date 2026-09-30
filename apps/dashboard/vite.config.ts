import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    proxy: {
      '^/(api|auth)': {
        target: process.env.API_URL || 'http://api:8000',
        changeOrigin: true,
      },
      '/protected': {
        target: 'http://dashboard:8080',
        changeOrigin: true,
      }
    }
  },
  optimizeDeps: {
    exclude: ['maplibre-gl']
  }
})
