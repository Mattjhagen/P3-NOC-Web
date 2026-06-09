/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        metro: {
          accent: "#00b4d8",
          bg: "#0f0f0f",
          surface: "#1a1a1a",
          muted: "rgba(255,255,255,0.35)",
        }
      },
      fontFamily: {
        sans: ['Inter', 'Segoe UI', 'sans-serif'],
        mono: ['Fira Code', 'Cascadia Code', 'Courier New', 'monospace'],
      },
      keyframes: {
        spin: {
          '0%': { transform: 'rotate(0deg)' },
          '100%': { transform: 'rotate(360deg)' },
        }
      },
      animation: {
        spin: 'spin 0.7s linear infinite',
      }
    },
  },
  plugins: [],
}
