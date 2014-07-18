log = console.log.bind console
d = document
use_storage = false

class Dragger

    is_active: false
    dragged_win: null
    resized_win: null
    prior_pos: null
    handle: null

    constructor: (@app) ->
        @addListeners @app.el

    addListeners: (el) ->
        el.addEventListener 'mousedown', @start, false
        el.addEventListener 'mousemove', @move, false
        el.addEventListener 'mouseup', @end, false

    # EVENTS #

    start: (evt) =>

        App.windowClicked evt.target # set selected

        @handle = evt.target.className

        @is_active = true
        @prior_pos = 
            x: evt.clientX
            y: evt.clientY
        win = App.getWindow evt.target

        if /bttn/.test @handle # window undo + redo bttns
            if @handle is 'un_bttn' then win.undo()
            if @handle is 're_bttn' then win.redo()
            return

        if @handle is 'title_bar'
            @dragged_win = win
            @dragged_win.setDragging true

        if /resize/.test @handle
            @resized_win = win
            @resized_win.setResizing true

        @app.initNewHistoryEvent evt

        win?.showoptionsMenu @handle

        if evt.button is 2 then log win.history
        
    move: (evt) =>
        if @is_active is true
            pos = 
                x: evt.clientX - @prior_pos.x
                y: evt.clientY - @prior_pos.y
            @dragged_win?.dragged pos.x, pos.y

            @resized_win?.resized pos.x, pos.y, @handle
            @prior_pos = 
                x: evt.clientX
                y: evt.clientY

    end: (evt) =>

        if @handle is 'win_ctrls' then App.handleMouseUp evt.target # handle close click

        if /bttn/.test @handle then return

        @handle = null
        @is_active = false
        @dragged_win?.setDragging false
        @dragged_win = null

        @resized_win?.setResizing false
        @resized_win = null
        
        @app.logHistoryEvent evt

class Win

    constructor: (x = 100, y = 100, w = 300, h = 200) ->
        @history = new HistoryManager @
        events.listenTo @history, 'change_logged', @historyEventLogged, @

        @pos = 
            x: x
            y: y
        @size =
            w: w
            h: h
        @initial = 
            pos: @pos
            size: @size
        @visible = true

        @el = d.createElement 'div'
        @el.className = 'win'
        @el.style.width = "#{@size.w}px"
        @el.style.height = "#{@size.h}px"
        @el.style.left = "#{@pos.x}px"
        @el.style.top = "#{@pos.y}px"

        bg = d.createElement 'div'
        bg.className = 'bg'
        @el.appendChild bg

        title_bar = d.createElement 'span'
        title_bar.className = 'title_bar'

        win_ctrls = d.createElement 'span'
        win_ctrls.className = 'win_ctrls'
        title_bar.appendChild win_ctrls
        win_opts = d.createElement 'span'
        win_opts.className = 'win_opts'
        title_bar.appendChild win_opts

        # options menu

        @options_menu = d.createElement 'span'
        @options_menu.className = 'options_menu hidden'
        undo_bttn = d.createElement 'button'
        undo_bttn.className = 'un_bttn'
        undo_bttn.textContent = '<–'
        @options_menu.appendChild undo_bttn
        redo_bttn = d.createElement 'button'
        redo_bttn.className = 're_bttn'
        redo_bttn.textContent = '–>'
        @options_menu.appendChild redo_bttn
        title_bar.appendChild @options_menu

        @el.appendChild title_bar

        @history_panel_el = d.createElement 'div'
        @history_panel_el.className = 'win_history'
        @el.appendChild @history_panel_el

        resize_top = d.createElement 'span'
        resize_top.className = 'resize top'
        # @el.appendChild resize_top

        resize_right = d.createElement 'span'
        resize_right.className = 'resize right'
        @el.appendChild resize_right

        resize_bot = d.createElement 'span'
        resize_bot.className = 'resize bot'
        @el.appendChild resize_bot

        resize_left = d.createElement 'span'
        resize_left.className = 'resize left'
        @el.appendChild resize_left

        resize_bot_right = d.createElement 'span'
        resize_bot_right.className = 'resize bot_right'
        @el.appendChild resize_bot_right

    update: (unused_id, history_event) ->

        @moveTo history_event.pos
        @resizeTo history_event.size
        @show history_event.visible

    moveTo: (pos) ->
        @pos.x = pos.x
        @pos.y = pos.y
        @el.style.left = "#{@pos.x}px"
        @el.style.top = "#{@pos.y}px"

    resizeTo: (size) ->

        @size.w = size.w
        @size.h = size.h
        @el.style.width = "#{@size.w}px"
        @el.style.height = "#{@size.h}px"

    dragged: (x, y) ->
        @pos.x += x
        @pos.y += y
        @el.style.left = "#{@pos.x}px"
        @el.style.top = "#{@pos.y}px"

    resized: (w, h, class_name) ->
        if /top/.test class_name
            @pos.y += h
            @size.h -= h
            @el.style.top = "#{@pos.y}px"
            @el.style.height = "#{@size.h}px"

        if /right/.test class_name
            @size.w += w
            @el.style.width = "#{@size.w}px"

        if /bot/.test class_name
            @size.h += h
            @el.style.height = "#{@size.h}px"

        if /left/.test class_name
            @pos.x += w
            @size.w -= w
            @el.style.left = "#{@pos.x}px"
            @el.style.width = "#{@size.w}px"

    setDragging: (frealz) ->
        @el.classList.toggle 'dragging'

    setResizing: (frealz) ->
        @el.classList.toggle 'resizing'

    show: (frealz) ->
        @visible = frealz
        if frealz is true then @el.classList.remove 'hidden'
        else @el.classList.add 'hidden'

    showoptionsMenu: (class_name) ->

        if /bttn/.test class_name then return

        if class_name is 'win_opts'
            @options_menu.classList.toggle 'hidden'
        else 
            @options_menu.classList.add 'hidden'

    undo: ->
        @history.stepBack()
        @updateHistoryPanel @history

    redo: ->
        @history.stepForward()
        @updateHistoryPanel @history

    historyEventLogged: (hist_mnr) ->
        @updateHistoryPanel hist_mnr

    updateHistoryPanel: (hist_mnr) ->
        @history_panel_el.innerHTML = ''
        for cng_evt, i in hist_mnr.change_events
            win_id = cng_evt.window_id
            action_name = 'moved to'
            vector_a = cng_evt.end.pos.x
            vector_b = cng_evt.end.pos.y
            time = new Date(cng_evt.timestamp).toTimeString().substring(0, 9)
            sel_class = if i is hist_mnr.index then ' selected' else ''

            item = d.createElement 'div'
            item.className = "history_item#{sel_class}"
            item.textContent = "#{action_name} #{vector_a}, #{vector_b} :: #{time}"
            
            @history_panel_el.appendChild item



class HistoryManager

    constructor: (@parent) ->
        @change_events = []
        @index = 0
        @prior_index = 0
        @temp_event = null
        @last_action = null # 'logged', 'undid' or 'redid'

    initTempLog: (win) -> @temp_event = @createNew win

    log: (win, tag) ->
        if @isANoChangeEvent(win) is true then return

        new_event = @finalizeEvent win, tag
        
        # clean up 

        if @index isnt @change_events.length
            @change_events = @change_events.slice 0, @index

        @change_events.push new_event
        events.dispatch 'change_logged', @

        @index += 1
        @last_action = 'logged'

        

        # papa = if @parent instanceof WindowManager then 'GLOBAL' else "win #{@parent.id}"
        # log papa, @change_events

    createNew: (win) ->

        init_event = 
            window_id: win.id
            start:
                pos:
                    x: win.pos.x
                    y: win.pos.y
                size:
                    w: win.size.w
                    h: win.size.h
                visible: win.visible
            timestamp: null
            end: null
            tag: 'tag'
            action: ''
    
    finalizeEvent: (win, tag) ->
        new_event = JSON.parse JSON.stringify(@temp_event)
        new_event.end =
            pos:
                x: win.pos.x
                y: win.pos.y
            size:
                w: win.size.w
                h: win.size.h
            visible: win.visible
        new_event.timestamp = Date.now()
        new_event.tag = tag
        new_event.action = @getActionType win
        @temp_event = null
        new_event

    popOutEvent: (history_step) ->
        change = (@change_events.filter (e) -> e.tag is history_step.tag)[0]
        if change?
            index = @change_events.indexOf change
            @change_events.splice index, 1
            log @change_events
            events.dispatch 'change_logged', @
            # if @index >= @change_events.length

    addBack: (step) ->
        already_event = (@change_events.filter (e) -> e.tag is step.tag)[0]
        log 'addBack', step
        if not already_event? and step?
            @change_events.push step
            events.dispatch 'change_logged', @

    stepBack: ->

        if @last_action isnt 'undid' and @index isnt @change_events.length - 1 then @decrement()
            
        @doundo()
        @decrement()

        @triggerEvent 'stepped_back' # for undo / redo buttons

    stepForward: ->

        if @last_action is 'undid' and @index isnt 0 then @increment()
        
        @redodo()
        @increment()

        @triggerEvent 'stepped_forward' # for undo / redo buttons

    # clear: ->

    triggerEvent: (event_name) -> 
        step = @change_events[@prior_index]
        events.dispatch event_name, @, step # for undo / redo buttons

    decrement: ->
        @index -= 1
        if @index < 0 then @index = 0; log 'no previous steps'

    increment: ->
        max_index = @change_events.length - 1
        @index += 1
        if @index > max_index then @index = max_index; log 'no newer steps'

    doundo: ->
        step = @change_events[@index]
        @parent.update step?.window_id, step?.start
        @last_action = 'undid'
        @prior_index = @index # to better sync history managers

    redodo: ->
        step = @change_events[@index]
        @parent.update step?.window_id, step?.end
        @last_action = 'redid'
        @prior_index = @index # to better sync history managers

    getStatus: ->
        is_undoable: @index > 0
        is_redoable: @index < @change_events.length - 1
        index: @index
        num_events: @change_events.length

    isANoChangeEvent: (win) ->
        inc = 0
        if @temp_event.start.pos.x is win.pos.x and @temp_event.start.pos.y is win.pos.y then inc += 1
        if @temp_event.start.size.w is win.size.w and @temp_event.start.size.h is win.size.h then inc += 1
        if @temp_event.start.visible is win.visible then inc += 1
        inc is 3

    getActionType: (win) ->
        type = 'unknown'
        if @temp_event.start.pos.x isnt win.pos.x or @temp_event.start.pos.y isnt win.pos.y
            type = 'moved'
        if @temp_event.start.size.w isnt win.size.w or @temp_event.start.size.h isnt win.size.h
            type = 'resized'
        if @temp_event.start.visible isnt win.visible
            type = 'closed'

        return type

    @getRandomTag: -> Math.random().toString(36).substring(2, 8)


class WinHistoryMngr extends HistoryManager

    step: null

    # constructor: (@win) -> super @win

    initTempLog: -> super @parent

    log: (tag) -> super @parent, tag

    doundo: ->
        @step = @change_events[@index]
        @parent.update @step?.start
        @last_action = 'undid'

    redodo: ->
        @step = @change_events[@index]
        @parent.update @step?.end
        @last_action = 'redid'

    triggerEvent: (event_name) ->
        events.dispatch event_name, @, @step # for undo / redo buttons

class WindowManager

    windows: []

    history: null

    colors: ['red', 'green', 'blue', 'orange', 'yellow', 'purple', 'cyan']

    constructor: (@app) ->
        @history = new HistoryManager @

    add: (win) ->
        win.id = @getNewId()
        win.el.classList.add @colors[win.id % @colors.length]

        # listen for pub sub event from each window ... for history sync

        events.listenTo win.history, 'stepped_back', @handleWinUndo, @
        events.listenTo win.history, 'stepped_forward', @handleWinRedo, @

        @windows.push win
        @app.el.appendChild win.el
        @setSelected win

    getNewId: -> @windows.length

    update: (id, history_event) ->
        win = @windows[id]
        
        win?.update null, history_event

    setSelected: (win) ->

        for w in @windows when w isnt win
            w.el.classList.remove 'selected'
            w.showoptionsMenu()
        win?.el.classList.add 'selected'

    getWindowsState: ->
        objs = []
        for w in @windows
            obj =
                id: w.id
                pos: w.pos
                size: w.size
            objs.push obj
        objs

    handleWinUndo: (dispatcher, step) -> @history.popOutEvent step

    handleWinRedo: (dispatcher, step) -> @history.addBack step
    

# GLOBAL EVENT DISPATCHER

class Events

    constructor: (context) ->
        @context = context
        @listeners = {}

    listenTo: (target, evt_name, callback, context) ->
        scope = if context? then context else @context
        new_listener = 
            target: target, 
            callback: callback, 
            context: scope

        if @listeners[evt_name]? then @listeners[evt_name].push new_listener
        else @listeners[evt_name] = [ new_listener ]
        return

    stopListening: (target, evt_name, callback) ->
        listeners = @listeners[evt_name]
        leftovers = []
        
        if listeners?
            for listener in listeners when not (listener.target is target and listener.callback is callback)
                leftovers.push listener
            @listeners[evt_name] = leftovers
        return

    isListening: (target, evt_name, callback) ->
        listeners = @listeners[evt_name]
        confirmed = []
        if listeners? 
            confirmed = listeners.filter (lsnr) -> 
                lsnr.target is target and lsnr.callback is callback
        return confirmed isnt []
        

    dispatch: (evt_name, caller, params) ->
        args = Array::slice.call arguments, 1
        listeners = @listeners[evt_name]
        
        doCallback = (listener) ->
            listener.callback.apply listener.context, args
            return

        if listeners? 
            doCallback listener for listener in listeners when listener.target is caller
        return
# END

App = 

    el: d.body.querySelector '.app'

    storage: window.localStorage

    start_time: Date.now()

    history_panel_el: null

    init: -> 
        window.events = new Events @
        @dragger = new Dragger @
        @win_manager = new WindowManager @

        d.addEventListener 'keydown', @appKeyed.bind(@), false

        # debug

        window.history = => @win_manager.history.change_events
        window.hStatus = => @win_manager.history.getStatus()
        window.hIndex = => @win_manager.history.index
        window.hLastAction = => @win_manager.history.last_action
        window.reset = => @reset()

        @layoutWindows()

        @addBBBar()
        @addHistoryPanel()

        # listen for pub sub event from history ... to re-render

        events.listenTo @win_manager.history, 'stepped_back', @handleHistoryEvent
        events.listenTo @win_manager.history, 'stepped_forward', @handleHistoryEvent
        events.listenTo @win_manager.history, 'change_logged', @historyEventLogged, @

    addNewWindow: (x = 100, y = 100, w = 400, h = 300) ->

        win = new Win x, y, w, h
        @win_manager.add win

        # if it's been more then a few moments, log new windows ... for undo purposes

        current_time = Date.now()
        if current_time - @start_time > 2000
            win.visible = false
            @win_manager.history.initTempLog win
            win.visible = true
            @win_manager.history.log win

    getWindow: (child_el) ->
        el = child_el.parentNode

        if not /win/.test el.className then el = el.parentNode # very simplistic error checking
        if el.className is 'title_bar' then el = el.parentNode # win options menu bttn clicked
        if el.className is 'win_ctrls' then el = el.parentNode # close clicked

        win = (@win_manager.windows.filter (w) -> w.el is el)[0]

    initNewHistoryEvent: (evt) ->
        win = @getWindow evt.target
        if win?
            @win_manager.history.initTempLog win

            # log window specific history too

            win.history.initTempLog win

    logHistoryEvent: (evt) ->
        win = @getWindow evt.target
        tag = HistoryManager.getRandomTag()

        if win?
            @win_manager.history.log win, tag

            # log window specific history too

            win.history.log win, tag

            @renderButtons()
            @save()

    handleHistoryEvent: (hist_mnr, change_event) ->
        @save()
        @updateHistoryPanel hist_mnr
        # @renderButtons status.is_undoable, status.is_redoable

    historyEventLogged: (hist_mnr) ->
        @updateHistoryPanel hist_mnr

    updateHistoryPanel: (hist_mnr) ->
        @history_panel_el.innerHTML = ''
        for cng_evt, i in hist_mnr.change_events
            win_id = cng_evt.window_id
            action_name = cng_evt.action
            vector_a = cng_evt.end.pos.x
            vector_b = cng_evt.end.pos.y
            time = new Date(cng_evt.timestamp).toTimeString().substring(0, 9)
            sel_class = if i is hist_mnr.index then ' selected' else ''

            item = d.createElement 'div'
            item.className = "history_item#{sel_class}"
            item.textContent = "win #{win_id} :: #{action_name} #{vector_a}, #{vector_b} :: #{time}"
            
            @history_panel_el.appendChild item
            

    layoutWindows: ->
        if use_storage is true and @storage.length isnt 0
            saved_windows = JSON.parse @storage.windows
            for win in saved_windows
                @addNewWindow win.pos.x, win.pos.y, win.size.w, win.size.h
        else
            @addNewWindow()
            @addNewWindow 510, 100, 400, 300
            @addNewWindow 100, 410, 400, 300
            @addNewWindow 510, 410, 400, 300

    reset: ->
        @storage.removeItem('windows')
        location.reload()

    addBBBar: ->
        bar = d.createElement 'div'
        bar.className = 'bbbar'
        undo_button = d.createElement 'button'
        undo_button.className = 'undo disabled'

        undo_button.textContent = 'UNDO (z)'
        bar.appendChild undo_button
        redo_button = d.createElement 'button'
        redo_button.className = 'redo disabled'
        redo_button.textContent = 'REDO (y)'
        bar.appendChild redo_button

        @el.appendChild bar

    addHistoryPanel: ->
        @history_panel_el = d.createElement 'div'
        @history_panel_el.className = 'history'
        
        @el.appendChild @history_panel_el



    renderButtons: (is_undoable = true, is_redoable = false) ->
        undo = @el.querySelector '.undo'
        redo = @el.querySelector '.redo'
        undo.classList[(if is_undoable then 'remove' else 'add')] 'disabled'
        redo.classList[(if is_redoable then 'remove' else 'add')] 'disabled'

    save: -> @storage.windows = JSON.stringify @win_manager.getWindowsState()

    # EVENTS

    appKeyed: (evt) ->
        Y = 89
        Z = 90
        N = 78
        H = 72
        ESC = 27
        TAB = 9
        key_pressed = evt.keyCode
        is_ctrl_keyed = true # evt.ctrlKey
        is_shifted = evt.shiftKey

        if key_pressed is Z and is_ctrl_keyed
            App.win_manager.history.stepBack()

        if key_pressed is Y and is_ctrl_keyed
            App.win_manager.history.stepForward()

        if key_pressed is N and is_ctrl_keyed
            @addNewWindow()

        if key_pressed is ESC
            @el.classList.toggle 'show_history'

        # log key_pressed

    windowClicked: (el) ->
        win = @getWindow el
        @win_manager.setSelected win

        # handle undo / redo button clicks

        if /undo/.test(el.className) then @win_manager.history.stepBack()

        if /redo/.test(el.className) then @win_manager.history.stepForward()


    handleMouseUp: (el) ->
        if el.className is 'win_ctrls' # close button el
            win = @getWindow el.parentNode
            win.show false

App.init()











      
