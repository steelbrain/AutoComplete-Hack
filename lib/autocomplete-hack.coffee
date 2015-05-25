require 'string_score'
Hack = require('./hack')

module.exports =
  activate:->
    if typeof atom.packages.getLoadedPackage("autocomplete-plus") is 'undefined'
      return Hack.showError("autocomplete-plus Package not found, but is required for to provide autocomplete.")
  provide:->
    Path = require('path')
    Hack.init()
    Provider =
      selector: '.source.cpp, .source.hack, .source.php'
      disableForSelector: '.comment'
      Map:{
        int: 'Integer'
        float: 'Float'
        string: 'String'
        bool: 'Boolean'
        array: 'Array'
        num: 'Number'
        mixed: 'Mixed'
      }
      getType:(Text, Label)->
        leftLabel = Label
        Type = Label
        if Label is 'class' or Text is '$this'
          Type = 'class'
          leftLabel = 'Class'
        else if typeof Provider.Map[Label] isnt 'undefined'
          Type = if Text.substr(0,1) is '$' then 'variable' else 'property'
          leftLabel = Provider.Map[Label]
        else
          Type = if Text.substr(0,1) is '$' then 'variable' else 'property'
          leftLabel = /(\w+)/.exec(Label)[0] || ''
        if leftLabel is 'function'
          Type = 'function'
        return {Type, leftLabel}
      getPrefix:(editor, bufferPosition)->
        regex = /::([\$\w0-9_-]+)$|\)\s*:(\w+)$|(:[\$\w0-9_-]+)$|([\$\w0-9_-]+)$/
        line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
        match = line.match regex
        return '' unless match
        return match[4] || match[3] || match[2] || match[1] || match[0]
      getSuggestions: ({editor, bufferPosition, scopeDescriptor}) ->
        return [] unless Hack.config.status
        prefix = Provider.getPrefix editor, bufferPosition
        Buffer = editor.getBuffer()
        Text = Buffer.getText()
        Index = Buffer.characterIndexForPosition(bufferPosition)
        Text = Text.substr(0, Index) + 'AUTO332' + Text.substr(Index)
        Command = "hh_client --auto-complete <<'EOFAUTOCOMPLETE'\n" + Text + "\nEOFAUTOCOMPLETE"
        new Promise (Resolve) ->
          Hack.exec(Command, Path.dirname(editor.getPath())).then (Result)->
            Result = Result.stdout.split("\n").filter((e) -> e)
            ToReturn = Result.map((Entry)->
              Entry = Entry.split(' ')
              Text = Entry[0]
              Label = Entry.slice(1).join(' ')
              {leftLabel, Type} = Provider.getType(Text, Label)
              return {
                type: Type
                text: Text
                leftLabel: leftLabel
                description: Label
                replacementPrefix: prefix
                score: prefix.length > 0 and Text.score(prefix)
              }
            )
            ToReturn.sort (a,b)=>
              b.score - a.score
            Resolve(ToReturn)
    return Provider