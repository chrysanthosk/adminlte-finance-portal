
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{ts,html}",
  ],
  theme: {
    extend: {
      colors: {
        dark: {
          bg: '#343a40',
          card: '#454d55',
          text: '#e2e8f0'
        }
      }
    }
  },
  plugins: [],
}
