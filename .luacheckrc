unused_secondaries = false
ignore = {
    '__'
}

files["**/i18n.lua"] = {
    max_line_length = false
}

files["**/info.lua"] = {
    max_line_length = false
}

files["**/test_calendars.lua"] = {
    max_line_length = false,
    ignore = {
        "211",
        "213",
        "311",
        "411",
        "421",
    }
}
