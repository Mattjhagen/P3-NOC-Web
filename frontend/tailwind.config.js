/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // High fidelity NOC theme
        dashboard: {
          bg: "#0B0C10",        // Deep outer space charcoal
          card: "#1F2833",      // Matte metal gray
          accent: "#45A29E",    // Muted cyber blue/teal
          neon: "#66FCF1",      // Vivid electric cyan
          border: "#2C3539",    // Gunmetal border lines
          healthy: "#10B981",   // Vibrant green
          warning: "#F59E0B",   // Warning orange/amber
          critical: "#EF4444",  // Emergency red
        }
      },
      fontFamily: {
        mono: ['Courier New', 'Courier', 'monospace'],
      },
      boxShadow: {
        'glow-neon': '0 0 15px rgba(102, 252, 241, 0.4)',
        'glow-healthy': '0 0 15px rgba(16, 185, 129, 0.4)',
        'glow-warning': '0 0 15px rgba(245, 158, 11, 0.4)',
        'glow-critical': '0 0 15px rgba(239, 68, 68, 0.4)',
      }
    },
  },
  plugins: [],
}
