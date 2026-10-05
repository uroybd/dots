def --wrapped task [...rest] {
    with-env { AWS_ENDPOINT_URL: "{{ TW_BUCKET }}" } {
        ^task sync o> /dev/null
        try {
          ^task ...$rest
        } catch { |err|
          print -e $"(ansi red_bold)Error executing task command:(ansi reset)\n($err)"
        }
        ^task sync o> /dev/null
    }
}
