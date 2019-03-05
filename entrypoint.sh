MY=(
    [ROLE]=app
    [RUN_AS]=www

    [INIT_URL]="${INIT_URL:-}"
    [INIT_POST]="${INIT_POST:-}"
    [INIT_PKGS]="${INIT_PKGS:-}"
    [CURL_OPTS]="${CURL_OPTS:-}"
    [GIT_BRANCH]="${GIT_BRANCH:-}"
    [KEEP_BOOTSTRAP_TOOLS]="${KEEP_BOOTSTRAP_TOOLS:-}"
    [PRE_WWWCONFIG]="${PRE_WWWCONFIG:-}"
    [POST_WWWCONFIG]="${POST_WWWCONFIG:-}"
    [OWN_WWWCONFIG]="${OWN_WWWCONFIG:-}"
)

passthrough_unless "php-fpm" "$@"

declare -r curl=( curl -sL "${MY[CURL_OPTS]}" )

handle_smartly () {
    local -r url="${1}"; shift

    case "${url}" in
        '')
            log 'No INIT_URL given.'
            return
            ;;
        git://*|ssh://*|git+ssh://*|*.git)
            if [[ -n "${MY[GIT_BRANCH]}" ]]; then
                git clone --branch "${MY[GIT_BRANCH]}" --depth=1 "${url}" .
            else
                git clone --depth=1 "${url}" .
            fi
            return
            ;;
    esac

    local -r file="$(basename "${url}")"
    local -r ext="${file#*.}"

    log "${file} is a '${ext}' file."

    case "${ext}" in
        tar.gz) "${curl[@]}" "${url}" | tar xvzf - ;;
        tar.bz2) "${curl[@]}" "${url}" | tar xvjf - ;;
        sh) "${curl[@]}" "${url}" | bash ;;
        *)
            log "Don't know what to do with ${file} from ${url}. Aborting."
            log "For complex deployment scenarios, try a .sh script as INIT_URL."
            return 1
            ;;
    esac
}

[[ -z "${MY[INIT_PKGS]}" ]] || apt-get install ${MY[INIT_PKGS]}

cd "${OUR[WEBDIR]}"
handle_smartly "${MY[INIT_URL]}"

if [[ -n "${MY[INIT_POST]}" ]]; then
    if [[ $(dirname "${MY[INIT_POST]}") = '.' ]]; then
        chmod +x "./${MY[INIT_POST]}"
    fi

    "${MY[INIT_POST]}"
fi

[[ -z "${MY[KEEP_BOOTSTRAP_TOOLS]}" ]] || apt-get purge curl

if have_global vhosts; then
    if [[ -n "${MY[PRE_WWWCONFIG]}" ]]; then
        echo "${MY[PRE_WWWCONFIG]}" > "${OUR[VHOSTS]}/default"
    fi

    {
        if [[ -n "${MY[OWN_WWWCONFIG]}" ]]; then
            echo "${MY[OWN_WWWCONFIG]}"
        else
            cat "${OUR[LOCAL_VHOSTS]}/default"
        fi
    } >> "${OUR[VHOSTS]}/default"

    if [[ -n "${MY[POST_WWWCONFIG]}" ]]; then
        echo "${MY[POST_WWWCONFIG]}" >> "${OUR[VHOSTS]}/default"
    fi

    reload_vhosts
fi

run "$@"
