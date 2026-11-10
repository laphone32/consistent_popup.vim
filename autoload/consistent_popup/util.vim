vim9script

export type EventFunctionType = func(): void
export def DummyEventFunction()
enddef

# Fixed-string, smart-case search (same semantics as `rg --smart-case
# --fixed-strings`): case-insensitive unless {keyword} has an uppercase
# letter. Returns [start, end) byte offsets in {text}, or [-1, -1].
export def Match(text: string, keyword: string): list<number>
    if empty(keyword)
        return [0, 0]
    endif
    var idx = -1
    if keyword =~# '\u'
        idx = stridx(text, keyword)
    else
        var lower = tolower(text)
        idx = stridx(lower, tolower(keyword))
        if idx >= 0 && len(lower) != len(text)
            # tolower() changed byte lengths (rare multibyte case); fall
            # back to a byte-safe position in the original text
            idx = match(text, '\V\c' .. escape(keyword, '\'))
        endif
    endif
    return idx < 0 ? [-1, -1] : [idx, idx + len(keyword)]
enddef

export def Matches(text: string, keyword: string): bool
    return Match(text, keyword)[0] >= 0
enddef

export def Error(msg: string)
    var full = 'consistent_popup: ' .. msg
    # echom does not set v:errmsg; do it so scripts (and tests) can see it
    v:errmsg = full
    echohl ErrorMsg | echom full | echohl None
enddef

export class SeriesTimer
    var id: number
    var stages: list<dict<number>>
    var stage: number
    var OnData: EventFunctionType = DummyEventFunction

    def new(this.OnData = v:none)
    enddef

    def Start(stages: list<dict<number>>, onData = this.OnData)
        this.id = -1
        this.stages = stages->copy()
        this.stage = 0
        this.OnData = onData

        this._OnTime(this.id)
    enddef

    def _OnTime(id: number)
        this.OnData()
        var session = this.stages[this.stage]

        if session.repeat == -1
            this.id = timer_start(session.period, (_) => this.OnData(), { repeat: -1 })
        elseif session.repeat == 0
            if this.stage < len(this.stages) - 1
                this.stage += 1
                session = this.stages[this.stage]
                this.id = timer_start(session.period, this._OnTime, { repeat: session.repeat })
            endif
        elseif session.repeat > 0
            session.repeat -= 1
        endif
    enddef

    def Stop()
        if this.id > 0
            this.id->timer_stop()
        endif
        this.id = -1
        this.stage = 0
        this.stages = []
    enddef
endclass

export class Timer
    var timer: SeriesTimer

    def new(onData = v:none)
        this.timer = SeriesTimer.new(onData)
    enddef

    def Start(period: number, repeat = -1)
        this.timer.Start([{
            period: period,
            repeat: repeat,
        }])
    enddef

    def Stop()
        this.timer.Stop()
    enddef

    def Restart(period: number, repeat = -1)
        this.Stop()
        this.Start(period, repeat)
    enddef
endclass

