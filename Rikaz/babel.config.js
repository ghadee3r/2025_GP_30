module.exports = function(api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [
      // 🚨 THIS IS THE CRITICAL LINE
      ['module:react-native-dotenv', {
        "envName": "APP_ENV",
        "moduleName": "@env",
        "path": ".env", // Points to your .env file
      }]
    ],
  };
};
