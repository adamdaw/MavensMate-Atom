{$, View} = require 'atom'
{Subscriber,Emitter} = require 'emissary'
emitter             = require('../mavensmate-emitter').pubsub
util                = require '../mavensmate-util'
moment              = require 'moment'

module.exports =
  # represents a single operation/command within the panel
  class MavensMatePanelViewItem extends View

    promiseId = null

    constructor: (command, params) ->
      super
      
      # set panel font-size to that of the editor
      fontSize = jQuery("div.editor-contents").css('font-size')
      @terminal.context.style.fontSize = fontSize
      
      # get the message
      message = @.panelCommandMessage params, command, util.isUiCommand params

      # scope this panel by the promiseId
      @promiseId = params.promiseId
      @item.attr 'id', @promiseId
      
      # write the message to the terminal
      @terminal.html message
      
    # Internal: Initialize mavensmate output view DOM contents.
    @content: ->
      @div class: 'panel-item',  =>
        @div outlet: 'item', =>
          @div class: 'container-fluid', =>
            @div class: 'row', =>
              @div class: 'col-md-12', =>
                @div =>
                  @pre class: 'terminal active', outlet: 'terminal'

    initialize: ->

    update: (panel, params, result) ->
      me = @
      command = util.getCommandName(params)
      if command not in util.panelExemptCommands()
        panelOutput = @getPanelOutput command, params, result
        # console.log 'panel output ---->'
        # console.log panelOutput

        # update progress bar depending on outcome of command
        # me.progress.attr 'class', 'progress'
        # me.progressBar.attr 'class', 'progress-bar progress-bar-'+panelOutput.indicator
        me.terminal.removeClass 'active'
        me.terminal.addClass panelOutput.indicator

        # update terminal
        me.terminal.append '<br/>> '+ '<span id="message-'+@promiseId+'">'+panelOutput.message+'</span>'
      return

    # returns the command message to be displayed in the panel
    panelCommandMessage: (params, command, isUi=false) ->
      # console.log params

      # todo: move objects to global?
      uiMessages =
        new_project : 'Opening new project panel'
        edit_project : 'Opening edit project panel'

      messages =
        new_project : 'Creating new project'
        compile_project: 'Compiling project'
        index_metadata: 'Indexing metadata'
        compile: ->
          if params.payload.files? and params.payload.files.length is 1
            'Compiling '+params.payload.files[0].split(/[\\/]/).pop() # extract base name
          else
            'Compiling selected metadata'
        delete: ->
          if params.payload.files? and params.payload.files.length is 1
            'Deleting ' + params.payload.files[0].split(/[\\/]/).pop() # extract base name
          else
            'Deleting selected metadata'
        refresh: ->
          if params.payload.files? and params.payload.files.length is 1
            'Refreshing ' + params.payload.files[0].split(/[\\/]/).pop() # extract base name
          else
            'Refreshing selected metadata'

      if isUi
        msg = uiMessages[command]
      else
        msg = messages[command]

      # console.log 'msgggggg'
      # console.log msg
      # console.log Object.prototype.toString.call msg

      if msg?
        if Object.prototype.toString.call(msg) is '[object Function]'
          msg = msg() + '...'
        else
          msg = msg + '...'
      else
        msg = 'mm '+command

      header = '['+moment().format('MMMM Do YYYY, h:mm:ss a')+']<br/>'
      return header + '> ' + msg

    # transforms the JSON returned by the cli into an object with properties that conform to the panel
    #
    # output =
    #   message: '(Line 17) Unexpected token, yada yada yada'
    #   indicator: 'success' #warning, danger, etc. (bootstrap label class names)
    #   stackTrace: 'foo bar bat'
    #   isException: true
    #
    getPanelOutput: (command, params, result) ->
      # console.log '~~~~~~~~~~~'
      # console.log command
      # console.log params
      # console.log result
      obj = null
      if params.args? and params.args.ui
        obj = @getUiCommandOutput command, params, result
      else
        try
          switch command
            when 'delete'
              obj = @getDeleteCommandOutput command, params, result
            when 'compile'
              obj = @getCompileCommandOutput command, params, result
            when 'compile_project'
              obj = @getCompileProjectCommandOutput command, params, result
            when 'run_all_tests', 'test_async'
              obj = @getRunAsyncTestsCommandOutput command, params, result
            when 'new_quick_trace_flag'
              obj = @getNewQuickTraceFlagCommandOutput command, params, result
            else
              obj = @getGenericOutput command, params, result
        catch
          obj = @getGenericOutput command, params, result

      return obj

    getDeleteCommandOutput: (command, params, result) ->
      if result.success
        obj = indicator: "success"
        if params.payload.files? and params.payload.files.length is 1
          obj.message = 'Deleted ' + util.baseName(params.payload.files[0])
        else
          obj.message = "Deleted selected metadata"
        return obj
      else
        @getErrorOutput command, params, result

    getUiCommandOutput: (command, params, result) ->
      # console.log 'parsing ui'
      if result.success
        obj =
          message: 'UI generated successfully'
          indicator: 'success'
        return obj
      else
        return @getErrorOutput command, params, result

    getErrorOutput: (command, params, result) ->
      output =
        message: result.body
        indicator: 'danger'
        stackTrace: result.stackTrace
        isException: result.stackTrace?

    getGenericOutput: (command, params, result) ->
      if result.body? and result.success?
        output =
          message: result.body
          indicator: if result.success then 'success' else 'danger'
          stackTrace: result.stackTrace
          isException: result.stackTrace?
      else
        output =
          message: 'No result message could be determined'
          indicator: 'warning'
          stackTrace: result.stackTrace
          isException: result.stackTrace?

    getCompileCommandOutput: (command, params, result) ->
      # console.log 'getCompileCommandOutput'
      obj =
        message: null
        indicator: null
        stackTrace: null
        isException: false

      filesCompiled = (util.baseName(filePath) for filePath in params.payload.files ? [])
      # console.log filesCompiled
      for compiledFile in filesCompiled
        atom.project.errors[compiledFile] = []

      if result.State? # tooling
        if result.state is 'Error' and result.ErrorMsg?
          obj.message = result.ErrorMsg
          obj.success = false
        else if result.State is 'Failed' and result.CompilerErrors?
          if Object.prototype.toString.call result.CompilerErrors is '[object String]'
            result.CompilerErrors = JSON.parse result.CompilerErrors

          errors = result.CompilerErrors
          message = 'Compile Failed'
          for error in errors
            errorFileName = error.name + ".cls"
            if error.line?
              errorMessage = "#{errorFileName}: #{error.problem[0]} (Line: #{error.line[0]})"
              error.lineNumber = error.line[0]
            else
              errorMessage = "#{errorFileName}: #{error.problem}"
            message += '<br/>' + errorMessage

            atom.project.errors[errorFileName] ?= []
            atom.project.errors[errorFileName].push(error)
          obj.message = message
          obj.indicator = 'danger'
          emitter.emit 'mavensmateCompileErrorBufferNotify', command, params, result
        else if result.State is 'Failed' and result.DeployDetails?
          errors = result.DeployDetails.componentFailures
          message = 'Compile Failed'
          for error in errors
            errorFileName = error.fileName + ".cls"
            if error.lineNumber
              errorMessage = "#{errorFileName}: #{error.problem} (Line: #{error.lineNumber})"
            else
              errorMessage = "#{errorFileName}: #{error.problem}"
            message += '<br/>' + errorMessage

            atom.project.errors[errorFileName] ?= []
            atom.project.errors[errorFileName].push(error)
          obj.message = message
          obj.indicator = 'danger'
          emitter.emit 'mavensmateCompileErrorBufferNotify', command, params, result 
        else if result.State is 'Completed' and not result.ErrorMsg
          obj.indicator = 'success'
          obj.message = 'Success'
          emitter.emit 'mavensmateCompileSuccessBufferNotify', params
        else
          #pass
      else if result.actions?
        # need to diff
        obj.message = result.body
        obj.indicator = 'warning'
      # else # metadata api
      #   #todo

      if !obj.message?
        throw 'unable to parse'

      return obj

    getCompileProjectCommandOutput: (command, params, result) ->
      obj =
        message: null
        indicator: null
        stackTrace: null
        isException: false

      if result.success?
        atom.project.errors = {}
        obj.success = result.success;
        if result.success
          obj.message = "Success"
          obj.indicator = 'success'
          emitter.emit 'mavensmateCompileSuccessBufferNotify', params
        else
          errors = result.Messages
          obj.indicator = 'danger'

          message = 'Compile Project Failed'
          for error in errors
            errorFileName = util.baseName(error.fileName)
            errorMessage = "#{errorFileName}: #{error.problem} (Line: #{error.lineNumber}, Column: #{error.columnNumber})"
            message += '<br/>' + errorMessage

            atom.project.errors[errorFileName] ?= []
            atom.project.errors[errorFileName].push(error)
          # console.log("Emitting mavensmateCompileErrorBufferNotify")
          # console.log(atom.project.errors)
          emitter.emit 'mavensmateCompileErrorBufferNotify', command, params, result

          obj.message = message
          obj.indicator = 'danger'
      return obj

    getRunAsyncTestsCommandOutput: (command, params, result) ->
      obj =
        message: null
        indicator: 'warning'
        stackTrace: ''
        isException: false

      passCounter = 0
      failedCounter = 0

      for apexClass in result
        for test in apexClass.detailed_results
          if test.Outcome == "Fail"
            failedCounter++
            obj.message = "#{failedCounter} failed test method"
            obj.message += 's' if failedCounter > 1
            obj.stackTrace += "#{test.ApexClass.Name}.#{test.MethodName}:\n#{test.StackTrace}\n\n"
          else
            passCounter++


      if failedCounter == 0
        obj.message = "Run all tests complete. #{passCounter} test" + (if passCounter > 1 then "s " else " ") + "passed."
        obj.indicator = 'success'
      else
        obj.indicator = 'danger'
        obj.isException = true

      return obj

    getNewQuickTraceFlagCommandOutput: (command, params, result) ->
      obj =
        message: null
        indicator: 'warning'
        stackTrace: ''
        isException: false

      if result.success is false
        obj.indicator = 'danger'
        obj.isException = true
        obj.stackTrace = result.stack_trace
      else
        obj.indicator = 'success'

      obj.message = result.body
      return obj