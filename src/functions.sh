#!/usr/bin/env bash
# Copyright (C) oxidio. See LICENSE file for license details.
# shellcheck source=.

function composerReplace() {
    local i rollback positional file path package packages dir=${PWD}

    for i in "$@"
    do
    case $i in
        --rollback)
        rollback=YES
        shift
        ;;

        *)
        positional+=("$1")
        shift
        ;;
    esac
    done
    set -- "${positional[@]}"

    path=$(realpath "composer.json" 2>/dev/null)

    [[ -n "$rollback" ]] || {
        dir=$(mktemp -d /tmp/composer-replace.XXXXX)
        cp composer.lock "$dir" 2>/dev/null
        php <<EOF
            <?php
            \$json = json_decode(file_get_contents('$path'), JSON_OBJECT_AS_ARRAY);
            \$json['repositories'][] = ['type' => 'path', 'url' => '$dir/*'];
            file_put_contents('$dir/composer.json', json_encode(\$json, JSON_PRETTY_PRINT));
EOF
    }

    for file in "$@"; do
        path=$(realpath "$file" 2>/dev/null)
        package=$(php -r "echo json_decode(file_get_contents('$path/composer.json'))->name;")
        packages+=" $package"
        oxidioBackup "vendor/$package"
        [[ -n "$rollback" ]] || {
            ln --backup=t -rs "$path" "$dir" 2>/dev/null
        }
    done

    COMPOSER="$dir/composer.json" \
    composer update --no-plugins --no-scripts --no-suggest "$packages"
}

function publicLinks() {
    local i quite dryRun line dst link rel base=${PWD}

    for i in "$@"
    do
    case $i in
        -q|--quite)
        quite=YES
        shift
        ;;

        --dry-run)
        dryRun=YES
        shift
        ;;

        *)
        ;;
    esac
    done

    for line in "$@"; do
        link=$(echo "$line"| cut -d: -f 1)
        dst=$(echo "$line"| cut -d: -f 2)
        if [[ -e ${base}/${link} ]]; then
            rel=${dst//[^\/]}
            rel=$(printf '../%.0s' $(seq 1 ${#rel}))

            [[ -n $dryRun ]] || {
                mkdir -p "$base/$dst" 2>/dev/null
                oxidioBackup "$base/$dst"
                ln -sf "$rel$link" "$base/$dst"
            }

            [[ -n $quite ]] || {
                echo "$base/$dst  ->  $rel$link"
            }
        fi
    done
}

function oxidioCreateSourceLinks() {
    local shop=${SHOP_URL##http*/}
    local theme=${SHOP_THEME:-flow}
    local rShared=${SHOP_RESOURCES_SHARED:-resources/shared}
    local rLocal=${SHOP_RESOURCES_LOCAL:-resources/local}
    local rTheme=${SHOP_RESOURCES_THEME:-resources/shared/theme}

    echo -e "\e[92m# create links: \e[44m shared assets \e[0m"
    publicLinks \
        "$rShared/downloads:source/out/downloads" \
        "$rShared/pictures/master:source/out/pictures/master" \
        "$rShared/pictures/media:source/out/pictures/media" \
        "$rShared/pictures/promo:source/out/pictures/promo" \
        "$rShared/pictures/vendor:source/out/pictures/vendor"

    echo -e "\e[92m# create links: \e[44m local assets \e[0m"
    publicLinks \
        "$rLocal/cache-data:source/tmp" \
        "$rLocal/cache-img:source/out/pictures/generated" \
        "$rLocal/log:source/log"

    echo -e "\e[92m# create links: \e[44m local '$shop' assets \e[0m"
    publicLinks \
        "$rLocal/$shop/cache-data:source/tmp" \
        "$rLocal/$shop/cache-img:source/out/pictures/generated" \
        "$rLocal/$shop/log:source/log"

    echo -e "\e[92m# create links: \e[44m theme '$theme' assets \e[0m"
    publicLinks \
        "$rTheme/bg:source/out/$theme/bg" \
        "$rTheme/css:source/out/$theme/src/css" \
        "$rTheme/fonts:source/out/$theme/src/fonts" \
        "$rTheme/img:source/out/$theme/img" \
        "$rTheme/js:source/out/$theme/src/js" \
        "$rTheme/theme.jpg:source/out/$theme/theme.jpg"
}

function oxidioCreateConfigIncPhp() {
    cat <<EOF > "${PWD}/source/config.inc.php"
<?php
/**
 * Copyright (C) oxidio. See LICENSE file for license details.
 */

call_user_func(function () {
    require __DIR__ . '/../vendor/autoload.php';
    require __DIR__ . '/config.inc.php.dist';
    /** @var OxidEsales\EshopCommunity\Core\Config|BootstrapConfigFileReader \$this */
    class_exists(Oxidio\Bootstrap::class) && Oxidio\Bootstrap::bootstrap(\$this);
});

EOF
}

function oxidioBackup() {
    local dir=${SHOP_BACKUP:-/tmp}
    mv --backup=t "$@" "$dir"  2>/dev/null
}
