Package.describe({
  name: 'herrbeesch:s3-media-functions',
  summary: 'extend s3 with some media functions',
  version: '0.0.25',
  git: 'https://github.com/herrBeesch/meteor-s3-media-functions.git'
});

Npm.depends({
	'awssum-riakcs': '1.2.0',
  'gm': '1.20.0',
  'request': '2.65.0',
  'png': '3.0.3',
  "fluent-ffmpeg": '2.0.1',
  'jszip': '2.5.0'
});

Package.onUse(function(api) {
  api.versionsFrom('METEOR@1.0.1');
  api.use('coffeescript');
  api.export('RiakCS', 'server');
  api.addFiles('psd.js', ['server', 'client']);
  api.addFiles('herrbeesch:s3-media-functions.coffee', 'server');
});

Package.onTest(function(api) {
  api.use('tinytest');
  api.use('coffeescript');
  api.use('herrbeesch:s3-media-functions');
  api.addFiles('herrbeesch:s3-media-functions-tests.coffee', 'server');
  api.addFiles('psd.js', ['server', 'client']);
});
