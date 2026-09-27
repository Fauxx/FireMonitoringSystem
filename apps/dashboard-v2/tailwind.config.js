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
          DEFAULT: '#0f172a', // Slate 900 - sleek and minimal
          light: '#334155',   // Slate 700
          dark: '#020617',    // Slate 950
        },
        accent: {
          DEFAULT: '#ef4444', // Red 500 - strictly for fire alerts
          light: '#fca5a5',   // Red 300
          dark: '#b91c1c',    // Red 700
        },
        surface: {
          DEFAULT: '#ffffff',
          dim: '#f8fafc',     // Slate 50
          border: '#e2e8f0',  // Slate 200
        }
      },
      boxShadow: {
        'glass': '0 4px 30px rgba(0, 0, 0, 0.05)',
      }
    },
  },
  plugins: [],
}
