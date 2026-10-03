def --wrapped task [...rest] {
    with-env { AWS_ENDPOINT_URL: "{{ TW_BUCKET }}" } {
        ^task ...$rest
    }
}
