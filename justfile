test:
    @for f in tests/*_spec.lua; do \
        nvim --headless -u NONE -c "set rtp^=." -l "$f" || exit 1; \
    done

lint:
    luacheck lua plugin tests

check: lint test
