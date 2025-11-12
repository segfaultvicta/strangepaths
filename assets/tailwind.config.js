// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

let plugin = require('tailwindcss/plugin')

module.exports = {
  darkMode: 'class', // Enable class-based dark mode
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex'
  ],
  safelist: [
    // Rumor map node colors - need to be safelisted for dynamic class generation
    'bg-red-200',
    'bg-blue-200',
    'bg-emerald-200',
    'bg-green-200',
    'bg-gray-200',
    'bg-purple-200',
    'border-red-500',
    'border-blue-500',
    'border-emerald-500',
    'border-green-500',
    'border-yellow-500',
    'border-white',
    'border-gray-500',
    'border-purple-500'
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/forms'),
    plugin(({ addVariant }) => addVariant('phx-no-feedback', ['&.phx-no-feedback', '.phx-no-feedback &'])),
    plugin(({ addVariant }) => addVariant('phx-click-loading', ['&.phx-click-loading', '.phx-click-loading &'])),
    plugin(({ addVariant }) => addVariant('phx-submit-loading', ['&.phx-submit-loading', '.phx-submit-loading &'])),
    plugin(({ addVariant }) => addVariant('phx-change-loading', ['&.phx-change-loading', '.phx-change-loading &']))
  ]
}
