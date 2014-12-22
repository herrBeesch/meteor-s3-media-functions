Package.describe({
  name: 'herrbeesch:s3-media-functions',
  summary: 'extend s3 with some media functions',
  version: '0.0.1',
  git: 'https://github.com/herrBeesch/meteor-s3-media-functions.git'
});

Npm.depends({
	'awssum-riakcs': '1.2.0',
  'gm': '1.17.0',
  'video-thumb': '0.0.2',
  'request': '2.51.0',
  'png': '3.0.3'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0.1');
  api.use('coffeescript');
  api.export('RiakCS', 'server');
  api.addFiles('herrbeesch:s3-media-functions.coffee', 'server');
});

Package.onTest(function(api) {
  api.use('tinytest');
  api.use('coffeescript');
  api.use('herrbeesch:s3-media-functions');
  api.addFiles('herrbeesch:s3-media-functions-tests.coffee', 'server');
  api.addFiles('psd.coffee', ['server', 'client']);
});
