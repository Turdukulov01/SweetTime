import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: 'class',
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        cream: {
          DEFAULT: '#FDF6ED',
          soft: '#FBF0E1',
          deep: '#F3E4CE',
        },
        pink: {
          50: '#FEF3F5',
          100: '#FCE0E5',
          200: '#F9C7D0',
          300: '#F6B8C4',
          400: '#EF97A8',
          500: '#E88FA0',
          600: '#D66E85',
          700: '#B24F67',
        },
        mint: {
          50: '#F1FBF7',
          100: '#DEF5EB',
          200: '#BFE8DC',
          300: '#9BDCC8',
          400: '#8FD3BE',
          500: '#5FB79E',
          600: '#3F8E77',
        },
        berry: {
          50: '#F7EDF0',
          100: '#E9CCD4',
          300: '#8A4D5D',
          500: '#5B2A3A',
          600: '#47212D',
          700: '#341820',
        },
        caramel: {
          100: '#F1E0C4',
          300: '#DDB878',
          500: '#C99A5B',
          600: '#A87A3E',
        },
        ink: {
          DEFAULT: '#4A3B3F',
          muted: '#8A7A7E',
        },
      },
      fontFamily: {
        display: ['var(--font-fraunces)', 'ui-serif', 'Georgia', 'serif'],
        body: ['var(--font-jakarta)', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['var(--font-mono)', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      borderRadius: {
        pearl: '999px',
        blob: '42% 58% 63% 37% / 41% 44% 56% 59%',
      },
      boxShadow: {
        soft: '0 4px 20px -4px rgba(91, 42, 58, 0.12)',
        lifted: '0 12px 32px -8px rgba(91, 42, 58, 0.22)',
        glow: '0 0 0 4px rgba(246, 184, 196, 0.35)',
      },
      keyframes: {
        'pearl-rise': {
          '0%': { transform: 'translateY(0) scale(0.8)', opacity: '0' },
          '15%': { opacity: '1' },
          '100%': { transform: 'translateY(-140%) scale(1)', opacity: '0' },
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' },
        },
        'fade-up': {
          '0%': { opacity: '0', transform: 'translateY(12px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        wobble: {
          '0%, 100%': { transform: 'rotate(-1.5deg)' },
          '50%': { transform: 'rotate(1.5deg)' },
        },
      },
      animation: {
        'pearl-rise': 'pearl-rise 2.4s ease-in-out infinite',
        shimmer: 'shimmer 1.8s ease-in-out infinite',
        'fade-up': 'fade-up 0.5s ease-out both',
        wobble: 'wobble 4s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};

export default config;
