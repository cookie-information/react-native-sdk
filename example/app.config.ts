import 'tsx/cjs';
import { ConfigContext, ExpoConfig } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  name: 'cookieinformationrnsdkexample',
  slug: 'cookieinformationrnsdkexample',
  version: '1.0.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  userInterfaceStyle: 'automatic',
  newArchEnabled: true,
  splash: {
    image: './assets/splash-icon.png',
    resizeMode: 'contain',
    backgroundColor: '#ffffff',
  },
  ios: {
    supportsTablet: false,
    bundleIdentifier: 'expo.modules.cookieinformationrnsdkexample',
  },
  android: {
    adaptiveIcon: {
      foregroundImage: './assets/adaptive-icon.png',
      backgroundColor: '#ffffff',
    },
    package: 'expo.modules.cookieinformationrnsdkexample',
  },
  web: {
    favicon: './assets/favicon.png',
  },
  plugins: [
    './src/assets/plugins/withMobileConsentsSDK.ts',
  ],
});
