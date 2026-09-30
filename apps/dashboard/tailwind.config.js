/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#ef4444', 
          light: '#f87171',
          dark: '#b91c1c',
        },
        base: {
          DEFAULT: '#ffffff', // White background
          light: '#f8fafc',   // slate-50
          dark: '#f1f5f9',    // slate-100
        },
        surface: {
          DEFAULT: '#ffffff', 
          dim: '#f8fafc',     // slate-50
          border: '#e2e8f0',  // slate-200
          muted: '#64748b',   // slate-500
        }
      },
      boxShadow: {
        'glass': '0 4px 30px rgba(0, 0, 0, 0.05)',
      }
    },
  },
  plugins: [],
}
