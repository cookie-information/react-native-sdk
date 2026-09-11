const reactNativeConfig = require('@react-native/eslint-config/flat');
const prettierConfig = require('eslint-config-prettier');
const ftFlowPlugin = require('eslint-plugin-ft-flow');
const prettierPlugin = require('eslint-plugin-prettier');

module.exports = [
  {
    ignores: ['build/**', 'example/**'],
  },
  // RN 0.87 bundles ft-flow v2, which uses APIs removed in ESLint 9.
  // Keep the RN rules, but run them with the compatible top-level plugin.
  ...reactNativeConfig.map((config) => {
    if (!config.plugins?.['ft-flow']) {
      return config;
    }

    return {
      ...config,
      plugins: {
        ...config.plugins,
        'ft-flow': ftFlowPlugin,
      },
    };
  }),
  prettierConfig,
  {
    plugins: {
      prettier: prettierPlugin,
    },
    rules: {
      'react/react-in-jsx-scope': 'off',
      'prettier/prettier': [
        'error',
        {
          quoteProps: 'consistent',
          singleQuote: true,
          tabWidth: 2,
          trailingComma: 'es5',
          useTabs: false,
        },
      ],
    },
  },
];
