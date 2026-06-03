module.exports = {
  dependency: {
    platforms: {
      ios: {},
      android: {
        packageImportPath: 'import com.cookieinformation.reactnative.CookieInformationRNSDKPackage;',
        packageInstance: 'new CookieInformationRNSDKPackage()',
      },
    },
  },
};
