# helper packages for test
temp    = require 'temp' # npm install temp
path    = require 'path' # npm install path

{WorkspaceView} = require 'atom'
emitter = require('../lib/mavensmate-emitter').pubsub
{panel} = require '../lib/mavensmate-panel-view'
{mm}    = require('../lib/mavensmate-cli')

describe 'MavensMate Panel View', ->
  beforeEach ->
    # set up the workspace
    atom.workspaceView = new WorkspaceView()
    atom.workspace = atom.workspaceView.model

    # activate the mavensmate package
    waitsForPromise ->
      atom.packages.activatePackage('mavensmate')

  it 'should be defined', ->
    expect(panel).toBeDefined()
    expect(panel).toBeDefined()
    expect(panel[0].outerText).toBe('MavensMate for Atom.io')
    expect(panel.myHeader).toBeDefined()
    expect(panel.myOutput).toBeDefined()



  describe 'Run All Tests (Async)', ->
    beforeEach ->
      # set up spy and ensure that calls are delegated
      spyOn(panel, 'getRunAsyncTestsCommandOutput').andCallThrough()
      spyOn(mm, 'run').andCallThrough()

    it 'should invoke mavensmate:run-all-tests-async', ->
      atom.workspaceView.trigger 'mavensmate:run-all-tests-async'
      expect(mm.run).toHaveBeenCalled()
      expect(mm.run.mostRecentCall.args[0].args.operation).toBe('run_all_tests')

    it 'should indicate when all tests passed', ->
      # create fake params object
      myParams =  {args: {operation: 'run_all_tests'}, promiseId: 'my-fake-promiseId'}
      successResponse = require('./fixtures/mavensmate-panel-view/test_success.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, successResponse, 'my-fake-promiseId'

      # ensure that getRunAsyncTestsCommandOutput has been called with expected params
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalled()
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalledWith('run_all_tests', myParams, successResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('Run all tests complete. 3 tests passed.')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')

    it 'should indicate when some tests have failed', ->
      # create fake params object
      myParams =  {args: {operation: 'run_all_tests'}, promiseId: 'my-fake-promiseId'}
      failureResponse = require('./fixtures/mavensmate-panel-view/test_failure.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, failureResponse, 'my-fake-promiseId'

      # ensure that getRunAsyncTestsCommandOutput has been called with expected params
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalled()
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalledWith('run_all_tests', myParams, failureResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('1 failed test method')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('SGToolKit_Batch_SendMessage_Test.shouldFail:\nClass.SGToolKit_Batch_SendMessage_Test.shouldFail: line 135, column 1\n\n')





  # Run unit tests for current class
  describe 'Run Async Unit Tests For This Class', ->
    beforeEach ->
      # set up the workspace with a fake test class
      directory = temp.mkdirSync()
      atom.project.setPath(directory)
      filePath = path.join(directory, 'MyTest.cls')
      spyOn(panel, 'getRunAsyncTestsCommandOutput').andCallThrough()
      spyOn(mm, 'run').andCallThrough()

      waitsForPromise ->
        atom.workspace.open(filePath)

    it 'should invoke mavensmate:run-async-unit-tests', ->
      atom.workspaceView.trigger 'mavensmate:run-async-unit-tests'
      expect(mm.run).toHaveBeenCalled()
      expect(mm.run.mostRecentCall.args[0].args.operation).toBe('test_async')
      expect(mm.run.mostRecentCall.args[0].payload.classes[0]).toBe('MyTest')

    it 'should indicate when all tests passed', ->
      myParams = {args: {operation: 'test_async'}, promiseId: 'my-fake-promiseId'}
      successResponse = require('./fixtures/mavensmate-panel-view/test_success.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, successResponse, 'my-fake-promiseId'

      # ensure that getRunAsyncTestsCommandOutput has been called with expected params
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalled()
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalledWith('test_async', myParams, successResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('Run all tests complete. 3 tests passed.')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')

    it 'should indicate when some tests have failed', ->
      myParams = {args: {operation: 'test_async'}, promiseId: 'my-fake-promiseId'}
      failureResponse = require('./fixtures/mavensmate-panel-view/test_failure.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, failureResponse, 'my-fake-promiseId'

      # ensure that getRunAsyncTestsCommandOutput has been called with expected params
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalled()
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalledWith('test_async', myParams, failureResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('1 failed test method')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('SGToolKit_Batch_SendMessage_Test.shouldFail:\nClass.SGToolKit_Batch_SendMessage_Test.shouldFail: line 135, column 1\n\n')




  # Fetch Logs
  describe 'Fetch Logs', ->
    it 'should indicate how many logs were fetched', ->
      myParams = {args: {operation: 'fetch_logs'}, promiseId: 'my-fake-promiseId'}
      response = require('./fixtures/mavensmate-panel-view/fetch_logs_4.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, response, 'my-fake-promiseId'

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('4 Logs successfully downloaded')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')