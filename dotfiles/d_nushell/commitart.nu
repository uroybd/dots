# Render a commit hash (piped in) as a grid of ANSI-colored blocks.
# Each hex character maps to one of the terminal theme's 16 ANSI colors,
# so equal hashes always look the same. --cols sets the blocks per row (default
# 8) and --block the string drawn for each cell (default "██"). --block may also
# be a comma-separated list, in which case the glyph is picked by the char's hex
# value (mod list length), just like the color. Since one ANSI color usually
# matches the terminal background, --bg names that color index and --bg-with the
# color drawn in its place (default: 0 -> 8). --offset left-pads every row with
# that many spaces.
def "commitart" [
    --cols: int = 8
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
] {
    let chars = $in | into string | split chars
    let blocks = $block | split row "," | each { str trim }
    let pad = 0..<$offset | each { " " } | str join

    mut out = ""
    mut i = 0
    for c in $chars {
        if ($i mod $cols) == 0 {
            $out = $out + $pad
        }
        let raw = $c | into int --radix 16
        let v = (if $raw == $bg { $bg_with } else { $raw })
        let glyph = $blocks | get ($raw mod ($blocks | length))
        $out = $out + (ansi -e $"38;5;($v)m") + $glyph + (ansi reset)
        $i = $i + 1
        if ($i mod $cols) == 0 {
            $out = $out + "\n"
        }
    }
    $out | str trim --right --char "\n"
}

def "commitart repo" [
    --cols: int = 8
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
    --short           # use the abbreviated commit hash (git rev-parse --short HEAD)
] {

    # Return early if not in a git repository. git exits 128 and writes to stderr
    # here, so swallow both with `do -i` + a redirect and inspect `complete`.
    let check = do -i { ^git rev-parse --is-inside-work-tree } | complete
    if $check.exit_code != 0 or ($check.stdout | str trim) != "true" {
        return
    }
    let hash = if $short { ^git rev-parse --short HEAD } else { ^git rev-parse HEAD }
    $hash | commitart --cols $cols --block $block --bg $bg --bg-with $bg_with --offset $offset
}
