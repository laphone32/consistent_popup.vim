vim9script

import "./util.vim" as ut

export class AsyncJob
    var _id: job
    var _OnData: func(string)
    # Bumped on every Start()/Stop(). job_stop() only signals the process, so
    # output already queued on the old channel can still arrive afterwards;
    # callbacks carrying an outdated generation are dropped.
    var _generation: number = 0

    def new(properties: dict<any>)
        this._id = null_job
        this._OnData = properties->get('onData', (_) => {
        })
    enddef

    def Start(properties: dict<any>)
        this.Stop()
        this._OnData = properties->get('onData', this._OnData)
        var gen = this._generation
        var opts: dict<any> = {
            in_io: 'null',
            out_cb: (_, message: string) => {
                if gen == this._generation
                    this._OnData(message)
                endif
            },
        }
        if properties->has_key('pty')
            opts.pty = properties.pty
        endif
        if properties->has_key('in_io')
            opts.in_io = properties.in_io
        endif
        var cmd = properties->get('cmd', ['/bin/sh', '-c', "echo \'No command for async job\'"])
        this._id = job_start(cmd, opts)
        if job_status(this._id) ==# 'fail'
            ut.Error('failed to start: ' .. string(cmd))
            this._id = null_job
        endif
    enddef

    def Stop()
        this._generation += 1
        if this._id != null_job
            this._id->job_stop()
            this._id = null_job
        endif
    enddef
endclass

