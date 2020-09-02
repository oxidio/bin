# Copyright (C) oxidio. See LICENSE file for license details.
# shellcheck source=.

function composerEnv() {
    local i dst env=dev project force package name

    for i in "$@"
    do
    case $i in
        --dst=*)
            dst="${i#*=}"
            shift
        ;;
        --env=*)
            env="${i#*=}"
            shift
        ;;
        --project=*)
            project="${i#*=}"
            shift
        ;;
        --force)
            force=YES
            shift
        ;;
    esac
    done

    [[ -n "$project" ]] || project=$(composerJsonAttr --delimiter="" "$PWD")
    [[ -n "$dst" ]] || dst=$(composer config -g data-dir)/env/$project/$env
    [[ -f "$dst/composer.json" ]] || force=YES
    [[ -n "$force" ]] && {
        rm -rf "$dst"
        mkdir -p "$dst/packages" 2>/dev/null
        php <<EOF
            <?php
            \$json = json_decode(file_get_contents('$PWD/composer.json'), JSON_OBJECT_AS_ARRAY);
            \$json['repositories'][] = ['type' => 'path', 'url' => '$dst/packages/*'];
            file_put_contents('$dst/composer.json', json_encode(\$json, JSON_PRETTY_PRINT));
EOF
        for i in $(composerJsonAttr "$@"); do
            package=$(echo "$i"| cut -d: -f 1)
            ln --backup=t -rs "$package" "$dst/packages" 2>/dev/null
        done
    }

    for i in $(composerJsonAttr "$dst"/packages/*); do
        name=$(echo "$i"| cut -d: -f 2)
        mv --backup=t "$PWD/vendor/$name" /tmp  2>/dev/null
    done

    echo "$dst/composer.json"
}

function composerJsonAttr() {
    local i path relative attr=name delimiter=:

    for i in "$@"
    do
    case $i in
        --relative)
            relative=YES
            shift
        ;;
        --attr=*)
            attr="${i#*=}"
            shift
        ;;
        --delimiter=*)
            delimiter="${i#*=}"
            shift
        ;;
    esac
    done

    for i in "$@"
    do
        path=$(realpath "$i" 2>/dev/null)
        [[ -f "$path/composer.json" ]] && {
            package=$(php -r "echo json_decode(file_get_contents('$path/composer.json'))->$attr;" 2>/dev/null)
            [[ -n "$relative" ]] && path="$i"
            [[ -n "$delimiter" ]] || path=
            echo "$path$delimiter$package"
        }
    done
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
