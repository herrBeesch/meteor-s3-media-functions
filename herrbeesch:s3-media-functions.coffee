RiakCS = Npm.require 'awssum-riakcs'
request = Npm.require 'request'

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
          when 'video/quicktime'
            toDos.push 'generate_thumbnail_from_video'
          when 'video/mp4'
            toDos.push 'generate_thumbnail_from_video'
          when 'image/vnd.adobe.photoshop'
            toDos.push 'generate_thumbnail_via_psdfileParser'
          when 'application/x-photoshop'
            toDos.push 'generate_thumbnail_via_psdfileParser'
          when 'application/octet-stream'
            if getFileExtension(objectName) is 'psd'
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
            tmpFile = "#{tmpPath}/#{new Date().getTime()}_#{removeFileExtension getFileName objectName}.#{origFileSuffix}"
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
                tmpThumbnailForGmReadyCallback = ()->
                  gmImage = gm(thumbFileForGm)
                  gmImage = gmImage.colorspace("RGB").flatten()
                  gmImage = gmImage.resize(thumbWidth, thumbHeight)
                  gmImage = gmImage.gravity("Center")
                  # gmImage = gmImage.background("white") 
                  # gmImage = gmImage.extent(thumbWidth, thumbHeight)
                  thumbFileForCloud = "#{tmpPath}/ce_#{Meteor.uuid()}_thumbnail.jpg"
                  tmpFileStream = fs.createWriteStream thumbFileForCloud
                  gmImage.stream('JPG').pipe tmpFileStream
                  filesToDelete.push thumbFileForGm
                  filesToDelete.push thumbFileForCloud
                  tmpFileStream
                    .on 'error', (err)->
                      for file in filesToDelete                        
                        fs.unlink file, (err)->
                          if err?
                            console.log "Error deleting #{file}"
                            console.log err
                      cb err, null
                    .on 'close', ()->
                      for file in filesToDelete                        
                        fs.unlink file, (err)->
                          if err?
                            console.log "Error deleting #{file}"
                            console.log err
                    .on 'finish', ()->
                      # console.log "finish"
                      stats = fs.statSync thumbFileForCloud
                      if stats? and stats.size?
                        tmpFileSize = stats.size
                        # upload to riak        
                        thumbObjectName = "#{prefix}#{removeFileExtension objectName}_thumbnail.jpg"
                        poOpts =
                          BucketName: thumbBucket
                          ObjectName: thumbObjectName
                          ContentType: "image/jpg"
                          ContentLength: tmpFileSize
                          Acl: acl
                          Body: fs.createReadStream thumbFileForCloud
                        self.PutObject poOpts, (err, result)->
                          if err?
                            console.log "Could not upload #{thumbObjectName}"
                            console.log thumbObjectName
                            console.log thumbFileForCloud                      
                            console.log err
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
                        for file in filesToDelete
                          fs.unlink file, (err)->
                            if err?
                              console.log "Error deleting #{file}"
                              console.log err
              
                # A) generate thumbnail via graphicsmagick from png, jpg, tiff, gif
                if toDos.indexOf('generate_thumbnail_via_gm') > -1
                  thumbFileForGm = tmpFile
                  tmpThumbnailForGmReadyCallback()
          
                # B) generate thumbnail (PNG !!!) via psd-file-parser from psd
                if toDos.indexOf('generate_thumbnail_via_psdfileParser') > -1
                  psd = Meteor.PSD.fromFile tmpFile
                  console.log "try to create thumb with psd"
                  pngThumbTmpFile = "#{tmpPath}/ce_psd_#{Meteor.uuid()}_thumbnail.png"
                  thumbFileForGm = pngThumbTmpFile                  
                  filesToDelete.push pngThumbTmpFile
                  try
                    psd.toFile pngThumbTmpFile, tmpThumbnailForGmReadyCallback
                  catch e
                    callback e, null
          
                # C) generate thumbnail via video-thumb from video
                if toDos.indexOf('generate_thumbnail_from_video') > -1
                  exec = Npm.require('child_process').exec
                  videoThumbTmpFile = "#{tmpPath}/ce_#{Meteor.uuid()}_video_thumbnail.jpg"
                  cmd = 'ffmpeg -i ' + tmpFile + ' -ss ' + '00:00:05' + ' -vframes 1  -an  -f image2 ' + videoThumbTmpFile 
                  thumbFileForGm = videoThumbTmpFile              
                  filesToDelete.push videoThumbTmpFile
                  try
                    exec cmd, tmpThumbnailForGmReadyCallback
                  catch e
                    callback e, null
          else
            callback "no etag in cloud object found.", null
  opts = 
    BucketName: bucketName
    ObjectName: objectName
  self.GetObjectMetadata opts, gotMetaDataCallback