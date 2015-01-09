RiakCS = Npm.require 'awssum-riakcs'
request = Npm.require 'request'
gm = Npm.require 'gm'
ffmpeg = Npm.require 'fluent-ffmpeg'

getFileExtension = (fileName)->
  fileSuffixRegex = /\.([0-9a-z]+)(?:[\?#]|$)/i
  ext = null
  if fileSuffixRegex.exec(fileName)?
    if fileSuffixRegex.exec(fileName).length is 1
      ext = fileSuffixRegex.exec(fileName)[0]
    else if fileSuffixRegex.exec(fileName).length > 1
      ext = fileSuffixRegex.exec(fileName)[1]
  return ext
removeFileExtension = (fileName)->
  fileSuffixRegex = /\.([0-9a-z]+)(?:[\?#]|$)/i
  fileNameWithoutExtension = null
  if fileSuffixRegex.exec(fileName)?
    if fileSuffixRegex.exec(fileName).length is 1
      fileNameExtension = fileSuffixRegex.exec(fileName)[0]
    else if fileSuffixRegex.exec(fileName).length > 1
      fileNameExtension = fileSuffixRegex.exec(fileName)[1]        
    fileNameWithoutExtension = fileName.replace fileSuffixRegex.exec(fileName)[0], ''
  return fileNameWithoutExtension
getFileName = (objName)->
  objName.split('/')[objName.split('/').length - 1]

RiakCS.S3.prototype.PutObjectHeaders = (BucketName, ObjectName, headers, callback)->
  self = this
  callback = _.once callback
  args = {
    method  : 'PUT',
    uri     : self.protocol() + '://' + BucketName + '.' + self.hostUrl + '/' + ObjectName,
    headers : headers,    
    aws     : {
      key: self.accessKeyId(),
      secret: self.secretAccessKey(),
      bucket: BucketName
    }
  }
  request args, callback
  .on 'error', (err)->
    console.log "CloudFunctions: Error in PutObjectHeaders"
    callback err, null

RiakCS.S3.prototype.UpdateObjectHeaders = (opts, headers, callback)->
  self = this
  callback = _.once callback
  self.GetObjectMetadata opts, (err, existingHeaders)->
    if err?
      console.log "CloudFunctions: Error in UpdateObjectHeaders"
      console.log "Error getting metadata from #{ObjectName}"
      console.log err
    else             
      headers = _.extend existingHeaders, headers 
      headers = _.extend headers, {
        'x-amz-copy-source': "#{opts.BucketName}/#{opts.ObjectName}",
        'x-amz-metadata-directive': 'REPLACE'
        'User-Agent': 'MeteorCloudFunctions'
      }
      headers = _.omit headers, ['content-length', 'server', 'etag', 'date', 'last-modified']
      self.PutObjectHeaders opts.BucketName, opts.ObjectName, headers, callback

RiakCS.S3.prototype.UpdateMetaThumbnailHeader = (opts, callback)->
  bucketName = opts.BucketName
  objectName = opts.ObjectName
  thumbBucket = opts.ThumbBucket
  thumbWidth = opts.ThumbWidth
  thumbHeight = opts.ThumbHeight
  if opts.HeaderKey?
    headerKey =  opts.HeaderKey 
  else
    headerKey = "x-amz-meta-preview-image-url"  
  acl = opts.Acl
  prefix  = opts.Prefix
  tmpPath = "#{opts.TempPath}/s3media_processes"
  self = this
  callback = _.once callback
  gotMetaDataCallback = (err, result)->
    if err?
      callback err, undefined
    else                
      if result.StatusCode isnt 200
        callback result, undefined
      else
        metaData = result.Headers      
        if metaData['content-type']?
          contentType = metaData['content-type']
        else if metaData['Content-Type']?
          contentType = metaData['Content-Type']
        toDos = []        
        # console.log contentType 
        switch contentType 
          when 'image/png'
            toDos.push 'generate_thumbnail_via_gm'
          when 'image/gif'
            toDos.push 'generate_thumbnail_via_gm'
          when 'image/jpg'
            toDos.push 'generate_thumbnail_via_gm'
          when 'image/jpeg'
            toDos.push 'generate_thumbnail_via_gm'
          when 'image/tiff'
            toDos.push 'generate_thumbnail_via_gm'
          when 'application/postscript'
            toDos.push 'generate_thumbnail_via_gm'
          when 'video/x-flv'
            toDos.push 'generate_thumbnail_via_ffmpeg'
          when 'video/quicktime'
            toDos.push 'generate_thumbnail_via_ffmpeg'
          when 'video/mp4'
            toDos.push 'generate_thumbnail_via_ffmpeg'
          when 'image/vnd.adobe.photoshop'
            toDos.push 'generate_thumbnail_via_psdfileParser'
          when 'application/x-photoshop'
            toDos.push 'generate_thumbnail_via_psdfileParser'
          when 'application/octet-stream'
            if getFileExtension(objectName).toLowerCase() is 'psd'
              console.log getFileExtension(objectName).toLowerCase()
              toDos.push 'generate_thumbnail_via_psdfileParser'
        if toDos.length is 0
          callback "Cannot create thumbnail from contentType: #{contentType}", null
        else
          if metaData['etag']?
            origObjectEtag = metaData['etag'].replace(/["']/g, "")        
            objUrl = "http://#{bucketName}.#{self.hostUrl}/#{objectName}"
            origFileSuffix = objectName.substr((objectName.lastIndexOf(".") >>> 0) + 1)
            try
              fs.mkdirSync tmpPath
            catch e
              console.log e unless e.code is 'EEXIST'
            wd = "#{tmpPath}/#{origObjectEtag}"
            try
              fs.mkdirSync wd
            catch e
              console.log e unless e.code is 'EEXIST'
            tmpFile = "#{wd}/#{removeFileExtension getFileName objectName}.#{origFileSuffix}"
            origFileStream = fs.createWriteStream(tmpFile)
            # download File from cloud
            request.get(objUrl).pipe(origFileStream)   
            #thumbnail generation
            origFileStream
              .on 'error', (err)->
                fs.unlink tmpFile, (err)->
                  if err?
                    console.log "Error deleting #{tmpFile}"
                    console.log err            
                callback err, null
              .on 'finish', ()->
                # file download done                          
                # steps to create similar thumbnails
                filesToDelete = [tmpFile]
                foldersToDelete = [wd]
                tmpThumbnailForGmReadyCallback = ()->
                  
                  gmImage = gm(thumbFileForGm)
                  gmImage = gmImage.colorspace("RGB").flatten()
                  gmImage = gmImage.resize(thumbWidth, thumbHeight)
                  gmImage = gmImage.gravity("Center")
                  # gmImage = gmImage.background("white") 
                  # gmImage = gmImage.extent(thumbWidth, thumbHeight)
                  tnContentType = 'jpg'
                  thumbFileForCloud = "#{wd}/thumbnail.#{tnContentType}"
                  tmpFileStream = fs.createWriteStream thumbFileForCloud
                  gmImage.stream(tnContentType).pipe tmpFileStream
                  filesToDelete.push thumbFileForGm
                  filesToDelete.push thumbFileForCloud
                  tmpFileStream
                    .on 'error', (err)->
                      for file in filesToDelete                        
                        fs.unlink file, (err)->
                          if err?
                            console.log "Error deleting #{file}"
                            console.log err
                      for folder in foldersToDelete
                        fs.rmdir folder, (err)->
                          if err?
                            console.log "Error deleting #{folder}"
                            console.log err
                      callback err, null
                    .on 'close', ()->
                      for file in filesToDelete
                        fs.unlink file, (err)->
                          if err?
                            console.log "Error deleting #{file}"
                            console.log err
                      for folder in foldersToDelete
                        fs.rmdir folder, (err)->
                          if err?
                            console.log "Error deleting #{folder}"
                            console.log err
                    .on 'finish', ()->
                      console.log "now finished"
                      stats = fs.statSync thumbFileForCloud
                      if stats? and stats.size?
                        # upload to riak                        
                        thumbObjectName = "#{prefix}#{removeFileExtension objectName}_thumbnail.#{tnContentType}"
                        poOpts =
                          BucketName: thumbBucket
                          ObjectName: thumbObjectName
                          ContentType: "image/#{tnContentType}"
                          ContentLength: stats.size
                          Acl: acl
                          Body: fs.createReadStream thumbFileForCloud
                        self.PutObject poOpts, (err, result)->
                          if err?
                            console.log "Could not upload #{thumbObjectName}"
                            console.log thumbObjectName
                            console.log thumbFileForCloud                      
                            console.log err
                            callback err, null
                          else
                            thumbObjUrl = "http://#{thumbBucket}.#{self.hostUrl}/#{thumbObjectName}"                  
                            if result.StatusCode is 200   
                              # update headers of object with metadata from thumbnail
                              headers = {}
                              headers["#{headerKey}"] = thumbObjUrl
                              uhOpts =
                                BucketName: bucketName
                                ObjectName: objectName
                              self.UpdateObjectHeaders uhOpts, headers, callback
                      else
                        console.log "Could not stat fileSize for #{thumbFileForCloud}"
              
                # A) generate thumbnail via graphicsmagick from png, jpg, tiff, gif
                if toDos.indexOf('generate_thumbnail_via_gm') > -1
                  thumbFileForGm = tmpFile
                  tmpThumbnailForGmReadyCallback()
          
                # B) generate thumbnail (PNG !!!) via psd-file-parser from psd
                if toDos.indexOf('generate_thumbnail_via_psdfileParser') > -1
                  # console.log "try to create thumb with psd"
                  try
                    psd = Meteor.PSD.fromFile tmpFile
                    thumbFileForGm = "#{wd}/tn.png"
                    psd.toFile thumbFileForGm, tmpThumbnailForGmReadyCallback
                  catch e
                    callback e, null
          
                # C) generate thumbnail via ffmpeg from video
                if toDos.indexOf('generate_thumbnail_via_ffmpeg') > -1                  
                  ffmpeg tmpFile
                    .on 'error', (err, stdout, stderr)-> 
                      console.log err
                      console.log stdout
                      console.log stderr
                      callback err, null
                    .on 'end', ()->
                      thumbFileForGm = "#{wd}/tn.png"
                      tmpThumbnailForGmReadyCallback()
                    .takeScreenshots({ count: 1, timemarks: [ '00:00:02.000'] }, wd)
          else
            callback "no etag in cloud object found.", null
  opts = 
    BucketName: bucketName
    ObjectName: objectName
  self.GetObjectMetadata opts, gotMetaDataCallback

RiakCS.S3.prototype.ExtractAudio  = (opts, callback)->
  sourceObjectName = opts.SourceObjectName
  sourceBucketName = opts.SourceBucketName
  targetObjectName = opts.TargetObjectName
  targetBucketName = opts.TargetBucketName
  acl = opts.Acl
  tmpPath = "#{opts.TempPath}/s3media_processes"
  self = this
  callback = _.once callback
  
  #get stream from source
  getOpts = 
    BucketName: sourceBucketName
    ObjectName: sourceObjectName
  tmpFile = "#{tmpPath}/#{sourceObjectName.replace /\//g, '_'}"  
  mp3File = "#{tmpPath}/#{sourceObjectName.replace /\//g, '_'}.mp3"  
  tmpFileStream = fs.createWriteStream tmpFile
  self.GetObject getOpts, {stream: true}, (err, data)->
    if err?
      callback err, null
    else
      #extract audio from video stream
      data.Stream.pipe tmpFileStream      
      tmpFileStream
        .on 'error', (err)->
          console.log err
          fs.unlink tmpFile, (err)->
            if err?
              console.log "could not delete #{tmpFile}"
              console.log err
          callback err, null
        .on 'finish', ()->
          ffmpeg tmpFile
            .on 'error', (err, stdout, stderr)-> 
              console.log err
              console.log stdout
              console.log stderr
              callback err, null
            .on 'end', ()->
              #upload the result
              stats = fs.statSync mp3File
              if stats? and stats.size?
                poOpts =
                  BucketName: targetBucketName
                  ObjectName: targetObjectName
                  ContentType: "audio/mpeg"
                  ContentLength: stats.size
                  Acl: acl
                  Body: fs.createReadStream mp3File
                self.PutObject poOpts, (err, result)->
                  if err?
                    console.log "Could not upload #{thumbObjectName}"
                    console.log thumbObjectName
                    console.log thumbFileForCloud
                    console.log err
                    callback err, null
                  fs.unlink mp3File, (err)->
                    if err?
                      console.log "could not delete #{mp3File}"
                  fs.unlink tmpFile, (err)->
                    if err?
                      console.log "could not delete #{tmpFile}"
                  callback null, result
              else
                callback "could not stat file", null
            .audioCodec('libmp3lame')
            .toFormat('mp3')
            .save(mp3File)
  
  