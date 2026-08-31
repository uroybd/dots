# Render a commit hash (piped in) as a grid of ANSI-colored blocks.
# Each hex character maps to one of the terminal theme's 16 ANSI colors,
# so equal hashes always look the same. --cols sets the blocks per row; 0 (the
# default) keeps the whole hash on one row. --block is the string drawn for each
# cell (default "██") and may be a comma-separated list, in which case the glyph
# is picked by the char's hex value (mod list length), just like the color. Since
# one ANSI color usually matches the terminal background, --bg names that color
# index and --bg-with the color drawn in its place (default: 0 -> 8). --offset
# left-pads every row with that many spaces. --half packs two hex chars into one
# terminal cell (left nibble = foreground, right nibble = background), so a short
# hash fits in half the width; the split glyph defaults to "▌" but --block
# overrides it (and a comma list is picked by the left nibble, like colors).
def "commitart" [
    --cols: int = 0
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
    --half
] {
    let chars = $in | into string | split chars
    let width = if $cols > 0 { $cols } else { [($chars | length) 1] | math max }
    let default_block = if $half { "▌" } else { "██" }
    let raw_block = if $block == "██" { $default_block } else { $block }
    let blocks = $raw_block | split row "," | each { str trim }
    let pad = 0..<$offset | each { " " } | str join
    let remap = {|n| if $n == $bg { $bg_with } else { $n } }

    $chars | chunks $width | each {|row|
        let cells = if $half {
            $row | chunks 2 | each {|pair|
                let lr = $pair | get 0 | into int --radix 16
                let l = do $remap $lr
                let glyph = $blocks | get ($lr mod ($blocks | length))
                if ($pair | length) == 2 {
                    let r = do $remap ($pair | get 1 | into int --radix 16)
                    (ansi -e $"38;5;($l);48;5;($r)m") + $glyph + (ansi reset)
                } else {
                    (ansi -e $"38;5;($l)m") + $glyph + (ansi reset)
                }
            }
        } else {
            $row | each {|ch|
                let raw = $ch | into int --radix 16
                let v = do $remap $raw
                let glyph = $blocks | get ($raw mod ($blocks | length))
                (ansi -e $"38;5;($v)m") + $glyph + (ansi reset)
            }
        }
        $pad + ($cells | str join)
    } | str join "\n"
}

def "commitart repo" [
    --cols: int = 0   # blocks per row; 0 keeps the whole hash on one row
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
    --short           # use the abbreviated commit hash (git rev-parse --short HEAD)
    --half            # pack two hex chars per terminal cell (see `commitart`)
] {

    # Return early if not in a git repository. git exits 128 and writes to stderr
    # here, so swallow both with `do -i` + a redirect and inspect `complete`.
    let check = do -i { ^git rev-parse --is-inside-work-tree } | complete
    if $check.exit_code != 0 or ($check.stdout | str trim) != "true" {
        return
    }
    let hash = if $short { ^git rev-parse --short HEAD } else { ^git rev-parse HEAD }
    $hash | commitart --cols $cols --block $block --bg $bg --bg-with $bg_with --offset $offset --half=$half
}

# Render commitart for the last N commits, one row each, next to the subject.
# --cols 0 (the default) fits every hash on a single line; all the other flags
# behave exactly as in `commitart`.
def "commitart log" [
    n: int = 10
    --cols: int = 0
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
    --short
    --half
    --bare            # print only the graphics, no hash or subject
] {
    let check = do -i { ^git rev-parse --is-inside-work-tree } | complete
    if $check.exit_code != 0 or ($check.stdout | str trim) != "true" {
        return
    }
    ^git log -n $n --pretty=format:'%H%x09%h%x09%s'
    | lines
    | each {|line|
        let p = $line | split row -n 3 "\t"
        let hash = if $short { $p.1 } else { $p.0 }
        let art = $hash | commitart --cols $cols --block $block --bg $bg --bg-with $bg_with --offset $offset --half=$half
        if $bare { $art } else { $"($art)  (ansi -e '2m')($p.1) ($p.2)(ansi reset)" }
    }
    | str join "\n"
}
