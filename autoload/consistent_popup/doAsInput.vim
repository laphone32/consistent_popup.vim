vim9script

if empty(prop_type_get('InputCursorStyle'))
    silent! prop_type_add('InputCursorStyle', {highlight: 'Directory', override: v:true})
else
    silent! prop_type_change('InputCursorStyle', {highlight: 'Directory', override: v:true})
endif

# {pos} and all slicing are in characters (Vim9 string indexing and slice()
# treat a base character plus its composing characters as one), so multibyte
# input such as CJK or accented letters edits correctly.
export class DoAsInput
    var id: number
    var buffer: string
    var pos: number
    var onType: func(string, string)

    def new(properties: dict<any>)
        this.buffer = properties->get('buffer', '')
        this.pos = strcharlen(this.buffer)
        this.onType = properties->get('onType', (key, all) => {
            })
        this.id = popup_dialog('', {
            minheight: 1,
            maxheight: 1,
            hidden: v:true,
            filter: this._KeyFilter
        }->extend(properties))
    enddef

    def _Before(): string
        return this.buffer->slice(0, this.pos)
    enddef

    def _After(offset: number = 0): string
        return this.buffer->slice(this.pos + offset)
    enddef

    def _Render()
        var before = this._Before()
        popup_settext(this.id, [{
            text: before .. '▏' .. this._After(),
            props: [{
                col: len(before) + 1,
                length: len('▏'),
                type: 'InputCursorStyle',
            }],
        }])
    enddef

    # Typed text, including multibyte characters and multi-character input
    # (e.g. an IME commit); rejects special keys and control characters.
    def _IsText(key: string): bool
        if empty(key) || key[0] ==# "\x80"
            return v:false
        endif
        return key !~ '[\x01-\x1f\x7f]'
    enddef

    def _KeyFilter(id: number, key: string): bool
        var handled = v:true
        var length = strcharlen(this.buffer)

        if key ==# "\<Left>" || key ==# "\<C-b>"
            this.pos = max([0, this.pos - 1])
        elseif key ==# "\<Right>" || key ==# "\<C-f>"
            this.pos = min([length, this.pos + 1])
        elseif key ==# "\<Home>" || key ==# "\<C-a>"
            this.pos = 0
        elseif key ==# "\<End>" || key ==# "\<C-e>"
            this.pos = length
        elseif key ==# "\<bs>" || key ==# "\<C-h>"
            if this.pos > 0
                this.buffer = this.buffer->slice(0, this.pos - 1) .. this._After()
                this.pos -= 1
            endif
        elseif key ==# "\<Del>" || key ==# "\<C-d>"
            if this.pos < length
                this.buffer = this._Before() .. this._After(1)
            endif
        elseif key ==# "\<C-u>"
            this.buffer = ''
            this.pos = 0
        elseif key ==# "\<C-w>"
            if this.pos > 0
                var trimmed = substitute(this._Before(), '\s*\k*$', '', '')
                this.buffer = trimmed .. this._After()
                this.pos = strcharlen(trimmed)
            endif
        elseif key ==# "\<esc>"
            popup_hide(this.id)
            return v:true
        elseif key ==# "\<cr>"
            popup_hide(this.id)
            this.onType(key, this.buffer)
            return v:true
        elseif this._IsText(key)
            this.buffer = this._Before() .. key .. this._After()
            this.pos += strcharlen(key)
        else
            handled = v:false
        endif

        if handled
            this._Render()
            this.onType(key, this.buffer)
        endif

        return v:true
    enddef

    def Open(properties = {})
        this.buffer = properties->get('buffer', '')
        this.pos = strcharlen(this.buffer)
        this.onType = properties->get('onType', this.onType)

        popup_setoptions(this.id, properties)
        this._Render()

        popup_show(this.id)
    enddef
endclass
