const path = require('path');

module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    [
      'module-resolver',
      {
        extensions: ['.tsx', '.ts', '.js', '.json'],
        alias: {
          '@cookieinformation/react-native-sdk': path.join(__dirname, '..', 'src'),
        },
      },
    ],
  ],
};
