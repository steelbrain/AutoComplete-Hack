
CP = require('child_process')
Path = require('path')
module.exports =
  config: type:'local', status:true
  SSH: null
  showError:(Message)->
    Notification = atom.notifications.addError("[Hack] #{Message}", {dismissable: true})
    setTimeout ->
      Notification.dismiss()
    , 5000
  showSuccess:(Message)->
    Notification = atom.notifications.addSuccess("[Hack] #{Message}", {dismissable: true})
    setTimeout ->
      Notification.dismiss()
    , 5000
  exec:(Command, CWD)->
    return new Promise (Resolve, Reject)=>
      if @config.type is 'remote'
        CWD = @config.remoteDir + '/' + Path.relative(atom.project.getPaths()[0], CWD).replace(Path.sep, '/');
        @SSH.exec(Command, {cwd: CWD}).then Resolve
      else
        CP.exec(Command, {cwd: CWD}, (error, stdout, stderr)->
          return Reject(error) if error
          Resolve({stdout, stderr});
        )
  init:->
    FS = require('fs')
    ProjectPaths = atom.project.getPaths()
    return unless ProjectPaths.length
    configPath = Path.join(ProjectPaths[0], '.atom-hack')
    try
      FS.accessSync(configPath, FS.R_OK)
    catch
      if process.platform is 'win32' then @showError("Could not find a .atom-hack config file")
      return
    FS.readFile configPath, (_, Contents)=>
      Contents = Contents.toString()
      try
        Contents = JSON.parse(Contents)
      catch then return @showError("Your .atom-hack file contains invalid JSON");
      Contents.status = true
      Contents.type = Contents.type || 'remote'
      Contents.port = Contents.port || 22
      @config = Contents
      return unless Contents.type is 'remote'
      return @showError("Please specify a privateKey") unless Contents.privateKey
      return @showError("Please specify a remoteDir") unless Contents.remoteDir
      try
        FS.accessSync(Contents.privateKey, FS.R_OK)
      catch then return @showError("Your private key file #{Contents.privateKey} is not accessible, Does it exist?");
      try
        @SSH = new (require('node-ssh'))(Contents)
      catch error
        return @showError(error.toString())
      @SSH.connect().then( =>
        @showSuccess("AutoComplete - Successfully Connected to Server")
      , (e)=>
        @showError("AutoComplete - Error Connecting to Server: " + e.toString())
      )
