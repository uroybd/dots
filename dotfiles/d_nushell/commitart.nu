# Render a commit hash (piped in) as a grid of ANSI-colored blocks.
# Each hex character maps to one of the terminal theme's 16 ANSI colors,
# so equal hashes always look the same. --cols sets the blocks per row; 0 (the
# default) keeps the whole hash on one row. --block is the string drawn for each
# cell (default "██") and may be a comma-separated list, in which case the glyph
# is picked by the char's hex value (mod list length), just like the color. Since
# one ANSI color usually matches the terminal background, --bg names that color
# index and --bg-with the color drawn in its place (default: 0 -> 8). --half
# packs two hex chars into one terminal cell (left nibble = foreground, right
# nibble = background), so a short hash fits in half the width; the split glyph
# defaults to "▌" but --block overrides it (and a comma list is picked by the
# left nibble, like colors). --centered-in gives a column width to center each
# row within (based on its actual rendered width, ignoring ANSI codes) -- it's
# 0 (disabled) by default. --offset left-pads every row with that many spaces,
# applied after centering (i.e. on top of the centering pad, shifting further
# right).
def "commitart" [
    --cols: int = 0
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
    --half
    --centered-in: int = 0
] {
    let chars = $in | into string | split chars
    let width = if $cols > 0 { $cols } else {
        [
            ($chars | length)
            1
        ] | math max
    }
    let default_block = if $half { "▌" } else { "██" }
    let raw_block = if $block == "██" { $default_block } else { $block }
    let blocks = $raw_block | split row "," | each { str trim }
    let spaces = {|n|
        if $n <= 0 { "" } else {
            0..<$n | each { " " } | str join
        }
    }
    let offset_pad = do $spaces $offset
    let remap = {|n|
        if $n == $bg { $bg_with } else { $n }
    }

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
        let rendered = $cells | str join
        let center_pad = if $centered_in > 0 {
            let vis_width = $rendered | ansi strip | split chars | length
            let gap = $centered_in - $vis_width
            do $spaces ((($gap | into float) / 2) | math floor | into int)
        } else {
            ""
        }
        $center_pad + $offset_pad + $rendered
    } | str join "\n"
}

# Pick a --cols value that lays `len` hex chars out in the most square grid
# possible. cols = ceil(sqrt(cells)), rows = ceil(cells/cols) is guaranteed to
# have cols >= rows, so it lands on an exact square when one exists and
# otherwise always leans landscape (wider than tall), never portrait. `cells`
# is `len`, or half that (rounded up) when --half packs two hex chars per cell.
def "commitart even-cols" [len: int, half: bool] {
    let cells = if $half {
        ($len | into float) / 2 | math ceil
    } else {
        $len | into float
    }
    let cols = $cells | math sqrt | math ceil | into int
    if $half { $cols * 2 } else { $cols }
}

def "commitart repo" [
    --cols: int = 0   # blocks per row; 0 keeps the whole hash on one row
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
    --short           # use the abbreviated commit hash (git rev-parse --short HEAD)
    --half            # pack two hex chars per terminal cell (see `commitart`)
    --even            # size the grid as square as possible (landscape over portrait when not exact); overrides --cols
    --centered-in: int = 0
] {

    # Return early if not in a git repository. git exits 128 and writes to stderr
    # here, so swallow both with `do -i` + a redirect and inspect `complete`.
    let check = do -i { ^git rev-parse --is-inside-work-tree } | complete
    if $check.exit_code != 0 or ($check.stdout | str trim) != "true" {
        return
    }
    let hash = if $short { ^git rev-parse --short HEAD } else { ^git rev-parse HEAD }
    let use_cols = if $even { commitart even-cols ($hash | str length) $half } else { $cols }
    $hash | commitart --cols $use_cols --block $block --bg $bg --bg-with $bg_with --offset $offset --half=$half --centered-in=$centered_in
}

# Truncate one rendered (possibly ANSI-colored) line to `width` visible
# characters, ANSI escape sequences (e.g. from `ansi -e`/`ansi reset`) don't
# count toward the width and are passed through untouched. A line that
# already fits is returned as-is; one that doesn't is cut and ellipsized (with
# a trailing reset so no color bleeds past it), so it never spills the width.
def "commitart truncate-line" [line: string, width: int] {
    if $width <= 0 { return $line }
    let chars = $line | split chars
    let total = $chars | length
    let ell = if $width > 3 { "..." } else { "" }
    let budget = $width - ($ell | str length)
    mut out = []
    mut visible = 0
    mut truncated = false
    mut i = 0
    while $i < $total {
        let ch = $chars | get $i
        if $ch == "\u{1b}" {
            mut seq = $ch
            mut j = $i + 1
            while $j < $total and (($chars | get $j) != "m") {
                $seq = $seq + ($chars | get $j)
                $j = $j + 1
            }
            if $j < $total {
                $seq = $seq + ($chars | get $j)
                $j = $j + 1
            }
            $out = ($out | append $seq)
            $i = $j
        } else if $visible < $budget {
            $out = ($out | append $ch)
            $visible = $visible + 1
            $i = $i + 1
        } else {
            $truncated = true
            break
        }
    }
    if $truncated {
        ($out | str join "") + $ell + (ansi reset)
    } else {
        $line
    }
}

# Render commitart for the last N commits, one row each, next to the subject.
# --cols 0 (the default) fits every hash on a single line; all the other flags
# behave exactly as in `commitart`. --max-width caps each rendered line's
# visible width (ANSI codes don't count), ellipsizing overflow so lines never
# spill over; it's ignored when --bare is set.
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
    --max-width: int = 0   # cap each line's visible width, ellipsizing overflow (ignored when --bare)
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
        let rendered = if $bare { $art } else { $"($art)  (ansi -e '2m')($p.1) ($p.2)(ansi reset)" }
        if (not $bare) and $max_width > 0 {
            $rendered | lines | each {|row| commitart truncate-line $row $max_width } | str join "\n"
        } else {
            $rendered
        }
    }
    | str join "\n"
}
