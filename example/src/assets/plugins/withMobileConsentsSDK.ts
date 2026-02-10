const { withPodfile } = require('@expo/config-plugins');

const withMobileConsentsSDK = config => {
  return withPodfile(config, config => {
    const podContent = config.modResults.contents;

    if (!podContent.includes("pod 'MobileConsentsSDK'")) {
      config.modResults.contents = podContent.replace(
        'use_expo_modules!',
        `use_expo_modules!\n  pod 'MobileConsentsSDK', :git => 'https://github.com/cookie-information/ios-release.git'`,
      );
    }

    return config;
  });
};

module.exports = withMobileConsentsSDK;
