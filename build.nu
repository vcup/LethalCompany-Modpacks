#! /usr/bin/env nu
use std log

const lethal_company_all_mods_url = 'https://thunderstore.io/c/lethal-company/api/v1/package'
const lethal_company_all_mods_db = 'lethal-company-all-mods.sqlite3'

def update_all_mods [] {
    let tempfile_path = (mktemp -t lethal_company_all_mods.XXXX.json)
    http get --raw $lethal_company_all_mods_url | save --progress -f $tempfile_path
    log info "[update_all_mods] database downloaded, converting as sqlite3."
    let all_mods = (open $tempfile_path | enumerate | each { |it| {
        main: ($it.item | reject versions categories | insert id $it.index)
        versions: ($it.item.versions | reject dependencies | insert mid $it.index),
        version_dependencies: ($it.item.versions | select uuid4 dependencies)
        categories: ($it.item.categories | each {|| {mid: $it.index, category: $in} })
    }})
    log info "[update_all_mods] prepared data structures."

    log info "[update_all_mods] remove existing sqlite database."
    rm -f $lethal_company_all_mods_db

    log info $"[update_all_mods] pumping 'main' table"
    $all_mods | get main | into sqlite $lethal_company_all_mods_db

    log info $"[update_all_mods] pumping 'versions' table"
    $all_mods | get versions | flatten | into sqlite -t versions $lethal_company_all_mods_db

    log info $"[update_all_mods] pumping 'version_dependencies' table"
    $all_mods | get version_dependencies | flatten | flatten | into sqlite -t version_dependencies $lethal_company_all_mods_db

    log info $"[update_all_mods] pumping 'categories' table"
    $all_mods | get categories | flatten | into sqlite -t categories $lethal_company_all_mods_db

    rm $tempfile_path
}

def 'main update-mods' [] {
    update_all_mods
}

def main [--lang-cn, --lang-jp, --mods-display, --mods-easier, --mods-misc, --mods-experience] {
    let manifest = open ($env.FILE_PWD  | path join mods.nuon)
    mut mods = $manifest | get required

    if $lang_cn {
        $mods = ($mods | append ($manifest | get optional.lang.cn))
    }
    if $lang_jp {
        $mods = ($mods | append ($manifest | get optional.lang.jp))
    }
    if $mods_display {
        $mods = ($mods | append ($manifest | get optional.display))
    }
    if $mods_easier {
        $mods = ($mods | append ($manifest | get optional.easier))
    }
    if $mods_misc {
        $mods = ($mods | append ($manifest | get optional.misc))
    }
    if $mods_experience {
        $mods = ($mods | append ($manifest | get optional.experience))
    }

    $mods
}
