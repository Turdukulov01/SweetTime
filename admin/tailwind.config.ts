import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        cream: {
          50: "#fffaf0",
          100: "#fff1d8",
          200: "#ffe2ad"
        },
        candy: {
          50: "#fff1f7",
          100: "#ffe3ef",
          300: "#ff9ec6",
          500: "#ff5c9a",
          700: "#c91f63"
        },
        mint: {
          50: "#effdf6",
          100: "#d8f8ea",
          300: "#8fe5c7",
          500: "#34c99a"
        },
        coffee: {
          500: "#7b4b35",
          700: "#4b2d22",
          900: "#251713"
        },
        // Акцент текущей компании (тенанта): RGB-триплет задаётся
        // CSS-переменной --accent в shell по company.accentColor.
        accent: "rgb(var(--accent) / <alpha-value>)"
      },
      fontFamily: {
        sans: ["var(--font-sans)", "Inter", "ui-sans-serif", "system-ui"]
      },
      boxShadow: {
        soft: "0 18px 60px rgba(124, 75, 53, 0.12)",
        glow: "0 0 0 1px rgba(255, 92, 154, 0.12), 0 20px 70px rgba(255, 92, 154, 0.18)"
      },
      keyframes: {
        shimmer: {
          "100%": { transform: "translateX(100%)" }
        }
      },
      animation: {
        shimmer: "shimmer 1.8s infinite"
      }
    }
  },
  plugins: []
};

export default config;
