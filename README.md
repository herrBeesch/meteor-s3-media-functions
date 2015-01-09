# s3-media-cloud-functions
##### meteor-package to do cool things with cloud files handled by s3

## Install

<pre>
  meteor add herrbeesch:s3-media-functions
</pre>

## implemented functions

### Generate Thumbnails from media files (images: PNG, GIF, JPG, PSD, EPS - Video: MOV, MPGEG, MP4)

### What does it do ?

#### UpdateMetaThumbnailHeader

It generates a thumbnail according to the settings, 
loads it into S3 and 
updates the original cloud object with a custom header with a link to the thumbnail-file.

e.g. 
x-amz-meta-preview-image-url: http://mythumbbucket.s3.mydomain/thumbnails/myfile_thumbnail.jpg

#### ExtractAudio

It extracts audio as mp3 from video and puts it as a new object


## Usage (coffeescript)
```coffeescript

  # Configure your s3-client (dependecy andruschka:awssum-riakcs)

  cloud = new RiakCS.S3({
    'accessKeyId'     : Meteor.settings.key_id,
    'secretAccessKey' : Meteor.settings.key_secret,
    'region'          : RiakCS.US_EAST_1
  }, "your-riakcs-url.com")

  # generate thumbnail of media object

  UMTHOpts = 
    BucketName: "BucketOfSourceObj"
    ObjectName: "NameOfSourceObj"
    ThumbBucket: "BucketToStoreThumbnails"
    ThumbWidth: 800
    ThumbHeight: 800
    Prefix: "thumbnails/"
    TempPath: "/tmp"
    Acl: "public-read"
    HeaderKey: "x-amz-meta-preview-image-url"
  cloud.UpdateMetaThumbnailHeader UMTHOpts, (err, result)->
    if err?
      console.log err
    else
      console.log result

  eaOpts = 
    SourceObjectName: "myCoolVideo.mp4"
    SourceBucketName: "videos"
    TargetObjectName: "audio_from_myCoolVideo.mp3"
    TargetBucketName: "audio"
    Acl: "public-read"
    TempPath: "/tmp"
  cloud.ExtractAudio eaOpts, Meteor.bindEnvironment (err, result)->
    if err?
      console.log err
    else
      console.log result
  
```

