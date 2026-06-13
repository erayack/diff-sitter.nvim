test:
    @for f in tests/*_spec.lua; do \
        nvim --headless -u NONE -c "set rtp^=." -l "$f" || exit 1; \
    done

format:
    stylua lua plugin tests

format-check:
    stylua --check lua plugin tests

lint:
    luacheck lua plugin tests

check: format-check lint test
